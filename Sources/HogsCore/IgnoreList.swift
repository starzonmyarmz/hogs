import Foundation

public final class IgnoreList {
    public static let defaultNames: Set<String> = ["kernel_task", "WindowServer"]
    static let key = "ignoredProcessNames"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard, legacyFile: URL? = IgnoreList.legacyFile) {
        self.defaults = defaults
        if defaults.stringArray(forKey: Self.key) == nil {
            var names = Self.defaultNames
            if let legacyFile, let text = try? String(contentsOf: legacyFile, encoding: .utf8) {
                names.formUnion(Self.parseLegacy(text))
            }
            defaults.set(names.sorted(), forKey: Self.key)
        }
    }

    public static let legacyFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/cpu-hogs/ignore")

    static func parseLegacy(_ text: String) -> Set<String> {
        Set(text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") })
    }

    public var names: Set<String> {
        Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    public func add(_ name: String) {
        defaults.set(names.union([name]).sorted(), forKey: Self.key)
    }

    public func remove(_ name: String) {
        defaults.set(names.subtracting([name]).sorted(), forKey: Self.key)
    }
}
