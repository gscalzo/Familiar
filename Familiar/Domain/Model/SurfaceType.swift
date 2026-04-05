public enum SurfaceType: Equatable, Sendable {
    case screenBottom
    case screenLeft
    case screenRight
    case screenTop
    case windowTop(windowID: Int)

    public var borderType: BorderType {
        switch self {
        case .screenBottom: .taskbar
        case .screenLeft, .screenRight: .vertical
        case .screenTop: .horizontal
        case .windowTop: .window
        }
    }
}
