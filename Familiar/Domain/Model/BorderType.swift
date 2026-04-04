struct BorderType: OptionSet, Sendable {
    let rawValue: Int
    static let none = BorderType(rawValue: 0x7F)
    static let taskbar = BorderType(rawValue: 0x01)
    static let window = BorderType(rawValue: 0x02)
    static let horizontal = BorderType(rawValue: 0x04)
    static let horizontalPlus = BorderType(rawValue: 0x06)
    static let vertical = BorderType(rawValue: 0x08)
}
