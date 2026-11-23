import Foundation

public struct Hog: Equatable, Sendable {
    public var process: ProcessSample
    public var rate: Double
    public var hotFor: Double
    public var ancestors: [String]
}

public struct HogTracker: Sendable {
    public struct Thresholds: Sendable {
        public var hotAt: Double
        public var staysHotAt: Double
        public var hotForSeconds: Double
        public var maxSampleGapSeconds = 5.0 * 60

        public init(hotAt: Double = 0.8, hotForSeconds: Double = 30 * 60) {
            self.hotAt = hotAt
            self.staysHotAt = hotAt - 0.2
            self.hotForSeconds = hotForSeconds
        }
    }

    struct Tracked: Sendable {
        var command: String
        var cpu: Double
        var sampledAt: Double
        var hotSince: Double?
        var rate: Double?
        var notified = false
        var snoozed = false
    }

    public var thresholds: Thresholds
    var tracked: [Int32: Tracked] = [:]
    private var latest: [Int32: ProcessSample] = [:]

    public init(thresholds: Thresholds = Thresholds()) {
        self.thresholds = thresholds
    }

    public mutating func update(_ processes: [Int32: ProcessSample], now: Double) {
        latest = processes
        tracked = tracked.filter { processes[$0.key] != nil }

        for (pid, p) in processes {
            guard let prev = tracked[pid], prev.command == p.command, p.cpuSeconds >= prev.cpu else {
                let lifetimeRate = p.elapsedSeconds > 0 ? p.cpuSeconds / p.elapsedSeconds : 0
                let hotSince = p.elapsedSeconds >= thresholds.hotForSeconds && lifetimeRate >= thresholds.hotAt
                    ? now - p.elapsedSeconds : nil
                tracked[pid] = Tracked(command: p.command, cpu: p.cpuSeconds, sampledAt: now, hotSince: hotSince)
                continue
            }

            var next = prev
            let gap = now - prev.sampledAt
            if gap > 0, gap <= thresholds.maxSampleGapSeconds {
                let rate = (p.cpuSeconds - prev.cpu) / gap
                next.rate = rate
                if next.hotSince == nil, rate >= thresholds.hotAt {
                    next.hotSince = now - gap
                } else if next.hotSince != nil, rate < thresholds.staysHotAt {
                    next.hotSince = nil
                    next.notified = false
                }
            }
            next.cpu = p.cpuSeconds
            next.sampledAt = now
            tracked[pid] = next
        }
    }

    public func hogs(ignoring ignored: Set<String>, now: Double) -> [Hog] {
        tracked.compactMap { pid, state -> Hog? in
            guard let p = latest[pid], !state.snoozed, !ignored.contains(p.name),
                  let hotSince = state.hotSince, now - hotSince >= thresholds.hotForSeconds
            else { return nil }
            let lifetimeRate = p.elapsedSeconds > 0 ? p.cpuSeconds / p.elapsedSeconds : 0
            return Hog(process: p, rate: state.rate ?? lifetimeRate, hotFor: now - hotSince, ancestors: ancestors(of: p))
        }
        .sorted { $0.hotFor > $1.hotFor }
    }

    public func needsNotification(_ pid: Int32) -> Bool {
        tracked[pid].map { !$0.notified } ?? false
    }

    public mutating func markNotified(_ pid: Int32) {
        tracked[pid]?.notified = true
    }

    public mutating func snooze(_ pid: Int32) {
        tracked[pid]?.snoozed = true
    }

    private func ancestors(of process: ProcessSample, limit: Int = 3) -> [String] {
        var result: [String] = []
        var current = latest[process.ppid]
        while let ancestor = current, ancestor.ppid != 0, result.count < limit {
            result.append(ancestor.command)
            current = latest[ancestor.ppid]
        }
        return result
    }
}
