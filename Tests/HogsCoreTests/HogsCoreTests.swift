import Foundation
import Testing

@testable import HogsCore

@Suite struct ProcessListTests {
    @Test func parsesDurations() {
        #expect(ProcessList.parseDuration("0:01.50") == 1.5)
        #expect(ProcessList.parseDuration("12:34") == 754)
        #expect(ProcessList.parseDuration("01:02:03") == 3723)
        #expect(ProcessList.parseDuration("2-01:00:00") == 2 * 86_400 + 3600)
    }

    @Test func parsesPsOutput() {
        let details = """
                1     0   1:00.00 3-00:00:00 /sbin/launchd
              512     1  45:00.00    01:00:00 /Applications/Some App.app/Contents/MacOS/Some App --flag
            """
        let names = """
                1 /sbin/launchd
              512 /Applications/Some App.app/Contents/MacOS/Some App
            """
        let procs = ProcessList.parse(details: details, names: names)
        #expect(procs.count == 2)
        #expect(procs[512]?.name == "Some App")
        #expect(procs[512]?.ppid == 1)
        #expect(procs[512]?.cpuSeconds == 2700)
        #expect(procs[512]?.elapsedSeconds == 3600)
        #expect(procs[512]?.command == "/Applications/Some App.app/Contents/MacOS/Some App --flag")
    }
}

@Suite struct HogTrackerTests {
    func sample(_ pid: Int32 = 42, cpu: Double, elapsed: Double, name: String = "busy") -> [Int32: ProcessSample] {
        [
            pid: ProcessSample(
                pid: pid, ppid: 1, cpuSeconds: cpu, elapsedSeconds: elapsed, command: "/bin/\(name)", name: name)
        ]
    }

    @Test func flagsProcessThatStaysBusyForThirtyMinutes() {
        var tracker = HogTracker()
        var cpu = 0.0
        tracker.update(sample(cpu: cpu, elapsed: 10), now: 0)
        for minute in 1...29 {
            cpu += 60
            tracker.update(sample(cpu: cpu, elapsed: 10 + Double(minute) * 60), now: Double(minute) * 60)
        }
        #expect(tracker.hogs(ignoring: [], now: 29 * 60).isEmpty)

        cpu += 60
        tracker.update(sample(cpu: cpu, elapsed: 10 + 30 * 60), now: 30 * 60)
        let hogs = tracker.hogs(ignoring: [], now: 30 * 60)
        #expect(hogs.count == 1)
        #expect(hogs.first?.rate == 1)
        #expect(tracker.hogs(ignoring: ["busy"], now: 30 * 60).isEmpty)
    }

    @Test func flagsLongRunningHogOnFirstSight() {
        var tracker = HogTracker()
        tracker.update(sample(cpu: 3600, elapsed: 3600), now: 10_000)
        #expect(tracker.hogs(ignoring: [], now: 10_000).count == 1)
    }

    @Test func coolingDownClearsHog() {
        var tracker = HogTracker()
        tracker.update(sample(cpu: 3600, elapsed: 3600), now: 0)
        tracker.update(sample(cpu: 3610, elapsed: 3660), now: 60)
        #expect(tracker.hogs(ignoring: [], now: 60).isEmpty)
    }

    @Test func snoozeHidesUntilProcessIsReplaced() {
        var tracker = HogTracker()
        tracker.update(sample(cpu: 3600, elapsed: 3600), now: 0)
        tracker.snooze(42)
        tracker.update(sample(cpu: 3660, elapsed: 3660), now: 60)
        #expect(tracker.hogs(ignoring: [], now: 60).isEmpty)

        tracker.update(sample(cpu: 3600, elapsed: 3600, name: "other"), now: 120)
        #expect(tracker.hogs(ignoring: [], now: 120).count == 1)
    }

    @Test func notifiesOnce() {
        var tracker = HogTracker()
        tracker.update(sample(cpu: 3600, elapsed: 3600), now: 0)
        #expect(tracker.needsNotification(42))
        tracker.markNotified(42)
        #expect(!tracker.needsNotification(42))
    }
}

@Suite struct IgnoreListTests {
    @Test func seedsDefaultsAndLegacyFile() throws {
        let defaults = UserDefaults(suiteName: "hogs-tests-\(UUID())")!
        let legacy = FileManager.default.temporaryDirectory.appendingPathComponent("hogs-ignore-\(UUID())")
        try "# comment\nnode\n\n  Slack  \n".write(to: legacy, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: legacy) }

        let list = IgnoreList(defaults: defaults, legacyFile: legacy)
        #expect(list.names == ["kernel_task", "WindowServer", "node", "Slack"])

        list.remove("node")
        list.add("ruby")
        #expect(
            IgnoreList(defaults: defaults, legacyFile: legacy).names == [
                "kernel_task", "WindowServer", "Slack", "ruby",
            ])
    }
}

@Suite struct PreferencesTests {
    func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "hogs-tests-\(UUID())")!
    }

    @Test func fallsBackToDefaults() {
        let thresholds = Preferences(defaults: freshDefaults()).thresholds
        #expect(thresholds.hotAt == 0.8)
        #expect(abs(thresholds.staysHotAt - 0.6) < 1e-9)
        #expect(thresholds.hotForSeconds == 30 * 60)
    }

    @Test func readsSavedValues() {
        let defaults = freshDefaults()
        let preferences = Preferences(defaults: defaults)
        preferences.hotAtPercent = 200
        preferences.hotForMinutes = 10
        let thresholds = Preferences(defaults: defaults).thresholds
        #expect(thresholds.hotAt == 2)
        #expect(thresholds.staysHotAt == 1.8)
        #expect(thresholds.hotForSeconds == 10 * 60)
    }

    @Test func readsMinutesWrittenAsString() {
        let defaults = freshDefaults()
        defaults.set("45", forKey: "hotForMinutes")
        #expect(Preferences(defaults: defaults).hotForMinutes == 45)
    }

    @Test func lowerThresholdFlagsSooner() {
        var tracker = HogTracker(thresholds: .init(hotAt: 0.5, hotForSeconds: 5 * 60))
        tracker.update(
            [
                42: ProcessSample(
                    pid: 42, ppid: 1, cpuSeconds: 0, elapsedSeconds: 10, command: "/bin/busy", name: "busy")
            ], now: 0)
        for minute in 1...5 {
            let sample = ProcessSample(
                pid: 42, ppid: 1, cpuSeconds: Double(minute) * 36, elapsedSeconds: 10 + Double(minute) * 60,
                command: "/bin/busy", name: "busy")
            tracker.update([42: sample], now: Double(minute) * 60)
        }
        #expect(tracker.hogs(ignoring: [], now: 5 * 60).count == 1)
    }
}

@Suite struct FormatTests {
    @Test func formatsDurations() {
        #expect(Format.duration(59) == "0m")
        #expect(Format.duration(45 * 60) == "45m")
        #expect(Format.duration(3 * 3600 + 120) == "3h 2m")
        #expect(Format.duration(2 * 86_400 + 3600) == "2d 1h")
    }

    @Test func truncates() {
        #expect(Format.truncate("a   b\tc", to: 10) == "a b c")
        #expect(Format.truncate("abcdefghij", to: 5) == "abcd…")
    }
}
