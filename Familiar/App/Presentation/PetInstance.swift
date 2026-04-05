import AppKit
import FamiliarDomain
import FamiliarInfrastructure

@MainActor
final class PetInstance: Identifiable {
    let id = UUID()
    let panel: PetPanel
    let stateMachine: AnimationStateMachine
    let spriteSheet: SpriteSheetLoader
    var name: String?

    var position: CGPoint = .zero
    var currentSurface: SurfaceType?
    var currentScreenIndex: Int = -1
    var currentInterval: Int = 100 // ms, updated by delegate
    var lastTickTime: CFTimeInterval = 0
    var isBeingKilled = false
    var killTickCount = 0

    init(
        panel: PetPanel,
        stateMachine: AnimationStateMachine,
        spriteSheet: SpriteSheetLoader,
        name: String? = nil
    ) {
        self.panel = panel
        self.stateMachine = stateMachine
        self.spriteSheet = spriteSheet
        self.name = name

        panel.onDragStart = { [weak self] in
            self?.currentSurface = nil
            self?.stateMachine.handleDragStart()
        }
        panel.onDragEnd = { [weak self] point in
            self?.position = point
            self?.currentSurface = nil
            self?.stateMachine.handleDragEnd()
        }
    }
}

// MARK: - AnimationStateMachineDelegate

extension PetInstance: AnimationStateMachineDelegate {
    nonisolated func stateMachine(_: AnimationStateMachine, didChangeFrame index: Int) {
        MainActor.assumeIsolated {
            let img = spriteSheet.image(at: index)
            panel.spriteView.image = img
        }
    }

    nonisolated func stateMachine(_: AnimationStateMachine, didMove dx: Int, dy: Int) {
        MainActor.assumeIsolated {
            // Don't move via state machine while user is dragging
            guard !stateMachine.isDragging else { return }
            position.x += CGFloat(dx)
            // Gravity boost: fall 2x faster for snappier drops
            let isFalling = dy > 0 && currentSurface == nil
            position.y -= CGFloat(dy) * (isFalling ? 2.0 : 1.0)
            panel.setFrameOrigin(position)
        }
    }

    nonisolated func stateMachine(_: AnimationStateMachine, didChangeOpacity opacity: Double) {
        MainActor.assumeIsolated {
            panel.alphaValue = CGFloat(opacity)
        }
    }

    nonisolated func stateMachine(_: AnimationStateMachine, didChangeInterval ms: Int) {
        MainActor.assumeIsolated {
            currentInterval = max(ms, 16) // minimum 16ms (~60fps)
        }
    }

    nonisolated func stateMachineDidRequestRespawn(_: AnimationStateMachine) {}

    nonisolated func stateMachineDidFlipSprites(_: AnimationStateMachine) {
        MainActor.assumeIsolated {
            spriteSheet.flipAllFrames()
        }
    }
}
