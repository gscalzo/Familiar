import Foundation

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    var multiScreenEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "multiScreenEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "multiScreenEnabled") }
    }

    var windowWalkingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "windowWalkingEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "windowWalkingEnabled") }
    }

    private init() {}
}
