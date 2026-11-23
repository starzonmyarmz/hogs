import Foundation

public final class Preferences {
    public static let hotAtPercentChoices = [50, 80, 100, 200]
    public static let hotForMinutesChoices = [5, 10, 15, 30, 60]
    static let hotAtPercentKey = "hotAtPercent"
    static let hotForMinutesKey = "hotForMinutes"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hotAtPercent: Int {
        get { read(Self.hotAtPercentKey, fallback: 80) }
        set { defaults.set(newValue, forKey: Self.hotAtPercentKey) }
    }

    public var hotForMinutes: Int {
        get { read(Self.hotForMinutesKey, fallback: 30) }
        set { defaults.set(newValue, forKey: Self.hotForMinutesKey) }
    }

    public var thresholds: HogTracker.Thresholds {
        HogTracker.Thresholds(hotAt: Double(hotAtPercent) / 100, hotForSeconds: Double(hotForMinutes) * 60)
    }

    private func read(_ key: String, fallback: Int) -> Int {
        let value = defaults.double(forKey: key)
        return value > 0 ? max(1, Int(value.rounded())) : fallback
    }
}
