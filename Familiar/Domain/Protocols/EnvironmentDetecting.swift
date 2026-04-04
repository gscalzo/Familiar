public protocol EnvironmentDetecting: AnyObject {
    func detectSurfaces() -> [WalkableSurface]
    func isFullScreenActive() -> Bool
    func currentScreenFrame() -> Rect
    func currentVisibleFrame() -> Rect
    func hasAdjacentScreen(at edge: ScreenEdge) -> Bool
}
