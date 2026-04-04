import AppKit
import FamiliarDomain
import FamiliarInfrastructure

@MainActor
final class PetInstance: Identifiable {
    let id = UUID()
    let panel: PetPanel
    let stateMachine: AnimationStateMachine
    let spriteSheet: SpriteSheetLoader

    var position: CGPoint = .zero
    var currentSurface: SurfaceType?

    init(
        panel: PetPanel,
        stateMachine: AnimationStateMachine,
        spriteSheet: SpriteSheetLoader
    ) {
        self.panel = panel
        self.stateMachine = stateMachine
        self.spriteSheet = spriteSheet

        panel.onDragStart = { [weak self] in
            self?.stateMachine.handleDragStart()
        }
        panel.onDragEnd = { [weak self] point in
            self?.position = point
            self?.stateMachine.handleDragEnd()
        }
        panel.onRemove = { [weak self] in
            guard let self else { return }
            _ = id // prevent unused warning; removal handled by PetManager
        }
    }
}

// MARK: - AnimationStateMachineDelegate

extension PetInstance: AnimationStateMachineDelegate {
    nonisolated func stateMachine(_: AnimationStateMachine, didChangeFrame index: Int) {
        MainActor.assumeIsolated {
            panel.spriteView.image = spriteSheet.image(at: index)
        }
    }

    nonisolated func stateMachine(_: AnimationStateMachine, didMove dx: Int, dy: Int) {
        MainActor.assumeIsolated {
            position.x += CGFloat(dx)
            position.y -= CGFloat(dy)
            panel.setFrameOrigin(position)
        }
    }

    nonisolated func stateMachine(_: AnimationStateMachine, didChangeOpacity opacity: Double) {
        MainActor.assumeIsolated {
            panel.alphaValue = CGFloat(opacity)
        }
    }

    nonisolated func stateMachine(_: AnimationStateMachine, didChangeInterval _: Int) {
        // Timer interval managed centrally by PetManager
    }

    nonisolated func stateMachineDidRequestRespawn(_: AnimationStateMachine) {
        // PetManager handles respawn positioning
    }

    nonisolated func stateMachineDidFlipSprites(_: AnimationStateMachine) {
        MainActor.assumeIsolated {
            spriteSheet.flipAllFrames()
        }
    }
}
