import AppKit
import FamiliarDomain

@MainActor
final class PetPanel: NSPanel {
    let spriteView: NSImageView
    var onDragStart: (() -> Void)?
    var onDragEnd: ((CGPoint) -> Void)?
    var onRemove: (() -> Void)?

    private var isDragging = false
    private var dragOffset: CGPoint = .zero

    init(frameSize: NSSize) {
        self.spriteView = NSImageView(frame: NSRect(origin: .zero, size: frameSize))

        super.init(
            contentRect: NSRect(origin: .zero, size: frameSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true

        spriteView.imageScaling = .scaleNone
        contentView = spriteView

        let trackingArea = NSTrackingArea(
            rect: NSRect(origin: .zero, size: frameSize),
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        contentView?.addTrackingArea(trackingArea)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        let loc = event.locationInWindow
        dragOffset = CGPoint(x: loc.x, y: loc.y)
        onDragStart?()
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let screenLoc = NSEvent.mouseLocation
        let newOrigin = CGPoint(
            x: screenLoc.x - dragOffset.x,
            y: screenLoc.y - dragOffset.y
        )
        setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        NSCursor.arrow.set()
        onDragEnd?(frame.origin)
    }

    override func mouseEntered(with event: NSEvent) {
        ignoresMouseEvents = false
        if !isDragging {
            NSCursor.openHand.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            ignoresMouseEvents = true
            NSCursor.arrow.set()
        }
    }

    // MARK: - Context Menu

    override func rightMouseDown(with event: NSEvent) {
        guard let view = contentView else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Remove This Pet", action: #selector(removePet), keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func removePet() {
        onRemove?()
    }
}
