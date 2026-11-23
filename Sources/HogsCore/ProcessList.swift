import Foundation

public struct ProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var ppid: Int32
    public var cpuSeconds: Double
    public var elapsedSeconds: Double
    public var command: String
    public var name: String

    public init(pid: Int32, ppid: Int32, cpuSeconds: Double, elapsedSeconds: Double, command: String, name: String) {
        self.pid = pid
        self.ppid = ppid
        self.cpuSeconds = cpuSeconds
        self.elapsedSeconds = elapsedSeconds
        self.command = command
        self.name = name
    }
}

public enum ProcessList {
    public static func parseDuration(_ text: String) -> Double {
        var rest = Substring(text)
        var days = 0.0
        if let dash = rest.firstIndex(of: "-") {
            days = Double(rest[..<dash]) ?? 0
            rest = rest[rest.index(after: dash)...]
        }
        var seconds = 0.0
        for part in rest.split(separator: ":") {
            seconds = seconds * 60 + (Double(part) ?? 0)
        }
        return days * 86_400 + seconds
    }

    public static func parse(details: String, names: String) -> [Int32: ProcessSample] {
        var nameByPID: [Int32: String] = [:]
        for line in names.split(separator: "\n") {
            let trimmed = line.drop(while: { $0 == " " })
            guard let space = trimmed.firstIndex(of: " "), let pid = Int32(trimmed[..<space]) else { continue }
            let comm = trimmed[space...].trimmingCharacters(in: .whitespaces)
            nameByPID[pid] = (comm as NSString).lastPathComponent
        }

        var result: [Int32: ProcessSample] = [:]
        for line in details.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard fields.count == 5, let pid = Int32(fields[0]), let ppid = Int32(fields[1]) else { continue }
            let command = String(fields[4])
            result[pid] = ProcessSample(
                pid: pid,
                ppid: ppid,
                cpuSeconds: parseDuration(String(fields[2])),
                elapsedSeconds: parseDuration(String(fields[3])),
                command: command,
                name: nameByPID[pid] ?? String(command.split(separator: " ").first ?? "")
            )
        }
        return result
    }

    public static func snapshot() throws -> [Int32: ProcessSample] {
        let details = try run(["-axo", "pid=,ppid=,time=,etime=,command="])
        let names = try run(["-axo", "pid=,comm="])
        return parse(details: details, names: names)
    }

    private static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
