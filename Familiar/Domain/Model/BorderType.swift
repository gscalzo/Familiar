public struct BorderType: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let none = BorderType(rawValue: 0x7F)
    public static let taskbar = BorderType(rawValue: 0x01)
    public static let window = BorderType(rawValue: 0x02)
    public static let horizontal = BorderType(rawValue: 0x04)
    public static let horizontalPlus: BorderType = [.window, .horizontal]
    public static let vertical = BorderType(rawValue: 0x08)
}
