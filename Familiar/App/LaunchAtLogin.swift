import Foundation

enum LaunchAtLogin {
    private static let plistPath: String = {
        let home = NSHomeDirectory()
        return "\(home)/Library/LaunchAgents/com.giordanoscalzo.familiar.plist"
    }()

    private static var executablePath: String {
        ProcessInfo.processInfo.arguments[0]
    }

    static var isEnabled: Bool {
        get { FileManager.default.fileExists(atPath: plistPath) }
        set {
            if newValue {
                enable()
            } else {
                disable()
            }
        }
    }

    private static func enable() {
        let plist: [String: Any] = [
            "Label": "com.giordanoscalzo.familiar",
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
        ]
        let dir = (plistPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        let data = try? PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        FileManager.default.createFile(atPath: plistPath, contents: data)
    }

    private static func disable() {
        try? FileManager.default.removeItem(atPath: plistPath)
    }
}
