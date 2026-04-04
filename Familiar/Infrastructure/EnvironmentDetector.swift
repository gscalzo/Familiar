import AppKit
import CoreGraphics
import FamiliarDomain

public final class EnvironmentDetector: EnvironmentDetecting {
    private var ownPanelWindowNumbers: Set<Int> = []

    public init() {}

    // Register our own pet panels so we exclude them from window detection
    public func registerOwnPanel(_ windowNumber: Int) {
        ownPanelWindowNumbers.insert(windowNumber)
    }

    public func unregisterOwnPanel(_ windowNumber: Int) {
        ownPanelWindowNumbers.remove(windowNumber)
    }

    // MARK: - EnvironmentDetecting

    public func detectSurfaces() -> [WalkableSurface] {
        var surfaces = screenEdgeSurfaces()

        if hasScreenRecordingPermission() {
            surfaces.append(contentsOf: windowTopSurfaces())
        }

        return surfaces
    }

    public func isFullScreenActive() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let screen = NSScreen.main
        else {
            return false
        }

        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        let screenFrame = screen.frame

        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  pid == frontApp.processIdentifier,
                  let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any]
            else {
                continue
            }

            let cgW = boundsDict["Width"] as? CGFloat ?? 0
            let cgH = boundsDict["Height"] as? CGFloat ?? 0

            if cgW >= screenFrame.width, cgH >= screenFrame.height {
                return true
            }
        }
        return false
    }

    public func currentScreenFrame() -> Rect {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        return Rect(
            origin: Vec2(x: frame.minX, y: frame.minY),
            width: frame.width,
            height: frame.height
        )
    }

    public func currentVisibleFrame() -> Rect {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1055)
        return Rect(
            origin: Vec2(x: frame.minX, y: frame.minY),
            width: frame.width,
            height: frame.height
        )
    }

    public func hasAdjacentScreen(at edge: ScreenEdge) -> Bool {
        guard let main = NSScreen.main else { return false }
        let mainFrame = main.frame

        for screen in NSScreen.screens where screen != main {
            let other = screen.frame
            switch edge {
            case .right:
                if abs(other.minX - mainFrame.maxX) < 2 { return true }
            case .left:
                if abs(mainFrame.minX - other.maxX) < 2 { return true }
            case .top:
                if abs(other.minY - mainFrame.maxY) < 2 { return true }
            case .bottom:
                if abs(mainFrame.minY - other.maxY) < 2 { return true }
            }
        }
        return false
    }

    // MARK: - Additional public methods (not in protocol)

    public func detectScreenEdgesOnly() -> [WalkableSurface] {
        detectSurfaces().filter { surface in
            switch surface.type {
            case .windowTop: false
            default: true
            }
        }
    }

    // MARK: - Private

    private func screenEdgeSurfaces() -> [WalkableSurface] {
        var surfaces: [WalkableSurface] = []
        for screen in NSScreen.screens {
            let visible = screen.visibleFrame
            let frame = screen.frame

            surfaces.append(WalkableSurface(
                rect: Rect(origin: Vec2(x: visible.minX, y: visible.minY), width: visible.width, height: 1),
                type: .screenBottom
            ))
            surfaces.append(WalkableSurface(
                rect: Rect(origin: Vec2(x: frame.minX, y: visible.minY), width: 1, height: visible.height),
                type: .screenLeft
            ))
            surfaces.append(WalkableSurface(
                rect: Rect(origin: Vec2(x: frame.maxX - 1, y: visible.minY), width: 1, height: visible.height),
                type: .screenRight
            ))
            surfaces.append(WalkableSurface(
                rect: Rect(origin: Vec2(x: visible.minX, y: visible.maxY - 1), width: visible.width, height: 1),
                type: .screenTop
            ))
        }
        return surfaces
    }

    private func windowTopSurfaces() -> [WalkableSurface] {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        var surfaces: [WalkableSurface] = []
        for window in windowList {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let windowNumber = window[kCGWindowNumber as String] as? Int,
                  !ownPanelWindowNumbers.contains(windowNumber)
            else {
                continue
            }

            let cgX = boundsDict["X"] as? CGFloat ?? 0
            let cgY = boundsDict["Y"] as? CGFloat ?? 0
            let cgW = boundsDict["Width"] as? CGFloat ?? 0
            let cgH = boundsDict["Height"] as? CGFloat ?? 0

            let nsRect = toNSCoords(CGRect(x: cgX, y: cgY, width: cgW, height: cgH))
            surfaces.append(WalkableSurface(
                rect: Rect(origin: Vec2(x: nsRect.minX, y: nsRect.maxY), width: nsRect.width, height: 1),
                type: .windowTop(windowID: windowNumber)
            ))
        }
        return surfaces
    }

    private func toNSCoords(_ cgRect: CGRect) -> CGRect {
        let screenH = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height ?? 0
        return CGRect(
            x: cgRect.origin.x,
            y: screenH - cgRect.origin.y - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    private func hasScreenRecordingPermission() -> Bool {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
        // If we can read window names, we have permission
        return windowList.contains { $0[kCGWindowName as String] != nil }
    }
}
