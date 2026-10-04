import Foundation
import CoreFoundation

enum HardwareScanner {
    struct Result { let items: [InventoryItem]; let error: String? }

    // These are read-only macOS inventory queries. A blank or missing result is
    // reported as unavailable rather than interpreted as a hardware failure.
    static func scan() -> Result {
        var items: [InventoryItem] = []
        var errors: [String] = []
        let sections: [(String, [String])] = [
            ("Kompiuteris", ["SPHardwareDataType"]),
            ("Baterija", ["SPPowerDataType"]),
            ("Ekranas ir grafika", ["SPDisplaysDataType"]),
            ("Atmintis", ["SPMemoryDataType"]),
            ("Saugykla", ["SPStorageDataType", "SPNVMeDataType"]),
            ("Kamera", ["SPCameraDataType"]),
            ("Garsas", ["SPAudioDataType"]),
            ("Wi‑Fi", ["SPWiFiDataType"]),
            ("Bluetooth", ["SPBluetoothDataType"]),
            ("USB jungtys", ["SPUSBDataType"]),
            ("Tinklo sąsajos", ["SPNetworkDataType"]),
        ]
        for (label, dataTypes) in sections {
            let output = run("/usr/sbin/system_profiler", ["-json"] + dataTypes)
            guard output.status == 0, let data = output.text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                if !output.text.isEmpty { errors.append("Nepavyko nuskaityti: \(label)") }
                continue
            }
            let summary = summarize(json)
            if !summary.isEmpty {
                items.append(.init(name: label, detail: summary, result: "Informacija"))
            }
        }
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        items.insert(.init(name: "macOS", detail: os, result: "Informacija"), at: 0)
        let disk = run("/usr/sbin/diskutil", ["info", "-plist", "/"])
        if disk.status == 0, let data = disk.text.data(using: .utf8),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            let free = (plist["FreeSpace"] as? NSNumber)?.int64Value
            let total = (plist["TotalSize"] as? NSNumber)?.int64Value
            if let free, let total {
                items.append(.init(name: "Pagrindinis tomas", detail: "Laisva \(bytes(free)) iš \(bytes(total))", result: "Informacija"))
            }
        }
        if items.count <= 1 && !errors.isEmpty {
            return Result(items: items, error: "Nepavyko surinkti sistemos informacijos. Patikrinkite, ar programa paleista macOS aplinkoje.")
        }
        return Result(items: items, error: errors.isEmpty ? nil : "Kai kurių duomenų macOS nepateikė: \(errors.joined(separator: ", ")).")
    }

    private static func run(_ executable: String, _ arguments: [String]) -> (status: Int32, text: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch { return (-1, error.localizedDescription) }
    }

    private static func summarize(_ value: Any) -> String {
        guard let dictionary = value as? [String: Any] else { return "" }
        var values: [String] = []
        func walk(_ object: Any, depth: Int) {
            guard depth < 4 else { return }
            if let dict = object as? [String: Any] {
                for (key, value) in dict {
                    if let string = value as? String, !string.isEmpty,
                       !key.hasPrefix("_"), !["_name", "_spcommand_line"].contains(key) {
                        let readableKey = key.replacingOccurrences(of: "_", with: " ")
                        values.append("\(readableKey): \(string)")
                    } else if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                        values.append("\(key.replacingOccurrences(of: "_", with: " ")): \(number)")
                    } else { walk(value, depth: depth + 1) }
                }
            } else if let array = object as? [Any] {
                for child in array { walk(child, depth: depth + 1) }
            }
        }
        walk(dictionary, depth: 0)
        return Array(NSOrderedSet(array: values)).compactMap { $0 as? String }.prefix(18).joined(separator: " · ")
    }

    private static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}
