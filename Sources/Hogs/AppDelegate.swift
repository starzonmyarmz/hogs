import AppKit
import HogsCore
import ServiceManagement
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let sampleInterval: TimeInterval = 60

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let ignoreList = IgnoreList()
    private var tracker = HogTracker()
    private var hogs: [Hog] = []
    private var timer: Timer?
    private let notificationsAvailable = Bundle.main.bundleIdentifier != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageLeading
        render()

        if notificationsAvailable {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        sample()
        timer = Timer.scheduledTimer(withTimeInterval: Self.sampleInterval, repeats: true) { _ in
            Task { @MainActor in self.sample() }
        }
        timer?.tolerance = 5
    }

    private func sample() {
        Task.detached(priority: .utility) {
            let processes = (try? ProcessList.snapshot()) ?? [:]
            await MainActor.run { self.apply(processes) }
        }
    }

    private func apply(_ processes: [Int32: ProcessSample]) {
        guard !processes.isEmpty else { return }
        let now = Date().timeIntervalSince1970
        tracker.update(processes, now: now)
        refreshHogs(now: now)
        for hog in hogs where tracker.needsNotification(hog.process.pid) {
            notify(hog)
            tracker.markNotified(hog.process.pid)
        }
    }

    private func refreshHogs(now: Double = Date().timeIntervalSince1970) {
        hogs = tracker.hogs(ignoring: ignoreList.names, now: now)
        render()
    }

    private func render() {
        guard let button = statusItem.button else { return }
        if hogs.isEmpty {
            button.image = PigIcon.template()
            button.attributedTitle = NSAttributedString()
            button.toolTip = "Hogs: no CPU hogs"
        } else {
            button.image = PigIcon.tinted(PigIcon.alertColor)
            button.attributedTitle = NSAttributedString(
                string: "\(hogs.count)",
                attributes: [
                    .foregroundColor: PigIcon.alertColor,
                    .font: NSFont.menuBarFont(ofSize: 0),
                    .baselineOffset: 1,
                ]
            )
            button.toolTip = hogs.count == 1 ? "Hogs: 1 CPU hog" : "Hogs: \(hogs.count) CPU hogs"
        }
    }

    private func notify(_ hog: Hog) {
        guard notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "CPU hog"
        content.body = "\(Format.truncate(hog.process.command, to: 60)) has been busy for \(Format.duration(hog.hotFor))"
        let request = UNNotificationRequest(identifier: "hog-\(hog.process.pid)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if hogs.isEmpty {
            menu.addItem(disabled("No CPU hogs"))
        }
        for hog in hogs {
            menu.addItem(item(for: hog))
        }

        menu.addItem(.separator())
        menu.addItem(ignoredItem())
        menu.addItem(launchAtLoginItem())
        menu.addItem(.separator())
        menu.addItem(disabled("Hogs \(Self.version)"))
        menu.addItem(NSMenuItem(title: "Quit Hogs", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(for hog: Hog) -> NSMenuItem {
        let p = hog.process
        let title = "\(Format.truncate(p.command, to: 50)) — \(Int((hog.rate * 100).rounded()))% for \(Format.duration(hog.hotFor))"
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.addItem(disabled("PID \(p.pid) · \(Format.truncate(p.name, to: 40))"))
        for ancestor in hog.ancestors {
            let line = disabled("↑ \(Format.truncate(ancestor, to: 70))")
            line.attributedTitle = NSAttributedString(
                string: line.title,
                attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor]
            )
            submenu.addItem(line)
        }
        submenu.addItem(.separator())
        submenu.addItem(action("Quit", #selector(quitProcess(_:)), p.pid))
        submenu.addItem(action("Force Quit", #selector(forceQuitProcess(_:)), p.pid))
        submenu.addItem(action("Copy PID", #selector(copyPID(_:)), p.pid))
        submenu.addItem(.separator())
        submenu.addItem(action("Ignore Until It Exits", #selector(snooze(_:)), p.pid))
        submenu.addItem(action("Always Ignore “\(Format.truncate(p.name, to: 40))”", #selector(alwaysIgnore(_:)), p.name))
        item.submenu = submenu
        return item
    }

    private func ignoredItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Ignored Processes", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let names = ignoreList.names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if names.isEmpty {
            submenu.addItem(disabled("None"))
        } else {
            submenu.addItem(disabled("Choose a process to stop ignoring it"))
            for name in names {
                submenu.addItem(action(name, #selector(stopIgnoring(_:)), name))
            }
        }
        item.submenu = submenu
        return item
    }

    private func launchAtLoginItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        item.target = self
        item.state = SMAppService.mainApp.status == .enabled ? .on : .off
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, _ value: Any) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.representedObject = value
        return item
    }

    // MARK: Actions

    @objc private func quitProcess(_ sender: NSMenuItem) {
        signal(sender, SIGTERM)
    }

    @objc private func forceQuitProcess(_ sender: NSMenuItem) {
        signal(sender, SIGKILL)
    }

    private func signal(_ sender: NSMenuItem, _ signal: Int32) {
        guard let pid = sender.representedObject as? Int32 else { return }
        if kill(pid, signal) != 0 {
            let alert = NSAlert()
            alert.messageText = "Couldn’t quit process \(pid)"
            alert.informativeText = String(cString: strerror(errno))
            NSApp.activate()
            alert.runModal()
            return
        }
        sample()
    }

    @objc private func copyPID(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? Int32 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(pid), forType: .string)
    }

    @objc private func snooze(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? Int32 else { return }
        tracker.snooze(pid)
        refreshHogs()
    }

    @objc private func alwaysIgnore(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        ignoreList.add(name)
        refreshHogs()
    }

    @objc private func stopIgnoring(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        ignoreList.remove(name)
        refreshHogs()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t change Launch at Login"
            alert.informativeText = error.localizedDescription
            NSApp.activate()
            alert.runModal()
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
