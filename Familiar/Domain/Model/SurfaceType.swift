public enum SurfaceType: Sendable {
    case screenBottom
    case screenLeft
    case screenRight
    case screenTop
    case windowTop(windowID: Int)
}
