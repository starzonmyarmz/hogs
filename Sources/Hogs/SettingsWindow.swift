import AppKit
import HogsCore
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindow {
    private let model: SettingsModel
    private lazy var window: NSWindow = {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Hogs Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        return window
    }()

    init(preferences: Preferences, onChange: @escaping () -> Void) {
        model = SettingsModel(preferences: preferences, onChange: onChange)
    }

    func show() {
        model.refreshLaunchAtLogin()
        if !window.isVisible {
            window.center()
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

@MainActor @Observable
final class SettingsModel {
    var hotAtPercent: Int {
        didSet {
            preferences.hotAtPercent = hotAtPercent
            onChange()
        }
    }

    var hotForMinutes: Int {
        didSet {
            preferences.hotForMinutes = hotForMinutes
            onChange()
        }
    }

    private(set) var launchAtLogin = false

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let onChange: () -> Void

    init(preferences: Preferences, onChange: @escaping () -> Void) {
        self.preferences = preferences
        self.onChange = onChange
        hotAtPercent = preferences.hotAtPercent
        hotForMinutes = preferences.hotForMinutes
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refreshLaunchAtLogin()
    }
}

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Busy at least", selection: $model.hotAtPercent) {
                    ForEach(choices(Preferences.hotAtPercentChoices, including: model.hotAtPercent), id: \.self) {
                        Text("\($0)% of a core")
                    }
                }
                Picker("For at least", selection: $model.hotForMinutes) {
                    ForEach(choices(Preferences.hotForMinutesChoices, including: model.hotForMinutes), id: \.self) {
                        Text(minutesLabel($0))
                    }
                }
            } footer: {
                Text("A process using several cores can go past 100%.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize()
    }

    private func choices(_ presets: [Int], including value: Int) -> [Int] {
        Set(presets + [value]).sorted()
    }

    private func minutesLabel(_ minutes: Int) -> String {
        if minutes == 60 { return "1 hour" }
        if minutes > 60, minutes % 60 == 0 { return "\(minutes / 60) hours" }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}
