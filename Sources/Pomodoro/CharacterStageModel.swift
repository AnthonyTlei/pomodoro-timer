import PomodoroCore
import PomodoroUI
import SwiftUI

// MARK: - Character stage state

/// What the character is doing right now.
@Observable
@MainActor
final class CharacterStageModel {
    var character: PomodoroCharacter = .none {
        didSet {
            if character != oldValue { isPerforming = false }
        }
    }
    var idleMode: CharacterIdleMode = .off
    var companionEdge: StageEdge = .top
    var companionPosition: Double = 0.5
    var companionActive = false
    var idleScreenBounds: CGRect = .null
    private(set) var isPerforming = false
    var showsCompanion: Bool {
        companionActive && idleMode != .off && character != .none && !isPerforming
    }
    /// The performance to play. Non-optional and always mounted: `KeyframeAnimator`
    /// only animates when its trigger *changes*, so one created fresh at the moment
    /// of the cue mounts with the trigger already final and never runs — it just
    /// renders its initial value, which is the fully hidden pose.
    var cue: CharacterCue = .breakStart
    /// Bumped per performance; this is what the animator watches.
    var generation: Int = 0
    /// True while a performance that steps in front of the pill is running.
    var foreground: Bool = false
    var edge: StageEdge = .top
    var pillScale: Double = 1

    /// How far the pill swells while a character performs.
    ///
    /// Deliberately one constant: it is the most likely thing to want retuning after
    /// seeing it on a real screen.
    static let reactionScale: Double = 1.15

    @ObservationIgnored private var clearTask: Task<Void, Never>?
    @ObservationIgnored private let performanceDuration: (CharacterCue, PomodoroCharacter) -> Double

    init(performanceDuration: @escaping (CharacterCue, PomodoroCharacter) -> Double = {
        CharacterPlan.duration(for: $0, character: $1)
    }) {
        self.performanceDuration = performanceDuration
    }

    func perform(_ cue: CharacterCue, character: PomodoroCharacter, edge: StageEdge) {
        guard character != .none, character.isImplemented else { return }

        clearTask?.cancel()
        self.character = character
        isPerforming = true
        self.edge = edge
        self.cue = cue
        self.foreground = CharacterPlan.comesForward(for: cue, character: character)

        // The trigger must change *after* this cue's animator has mounted.
        //
        // Each cue is a different `Keyframes` type, so switching cue replaces the
        // animator with a new instance. Bumping generation in the same update meant
        // the replacement mounted with its trigger already final — and
        // KeyframeAnimator only animates on a *change*, so it sat at its initial
        // pose. One runloop turn apart is enough.
        DispatchQueue.main.async { [weak self] in
            self?.generation += 1
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            pillScale = Self.reactionScale
        }

        let duration = performanceDuration(cue, character)
        clearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            // The pill relaxing is the full stop at the end of the sentence, so it
            // starts only once the character has finished dropping.
            withAnimation(.smooth(duration: 0.45)) { self.pillScale = 1 }
            // The mini yields until the original performance and pill relaxation
            // have finished. Cancelling a superseded performance cannot reveal it.
            try? await Task.sleep(for: .seconds(0.45))
            guard !Task.isCancelled else { return }
            self.isPerforming = false
        }
    }

    /// Await the active performance's actual completion rather than racing the
    /// main actor with a guessed wall-clock sleep in lifecycle verification.
    func settlePerformance() async { await clearTask?.value }
}
