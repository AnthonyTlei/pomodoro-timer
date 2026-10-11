import PomodoroCore
import Testing
@testable import Pomodoro

@Suite("Idle companion lifecycle")
@MainActor
struct IdleCompanionLifecycleTests {
    @Test("Off, no character, and a hidden bar never run an idle companion")
    func optInAndVisibility() {
        let stage = CharacterStageModel()
        stage.character = .samurai
        stage.companionActive = true
        #expect(!stage.showsCompanion)
        stage.idleMode = .calm
        #expect(stage.showsCompanion)
        stage.companionActive = false
        #expect(!stage.showsCompanion)
        stage.companionActive = true
        stage.character = .none
        #expect(!stage.showsCompanion)
    }

    @Test("Every character yields to a performance and returns after it finishes",
          arguments: PomodoroCharacter.allCases.filter { $0 != .none })
    func performanceHandoff(character: PomodoroCharacter) async throws {
        let stage = CharacterStageModel(performanceDuration: { _, _ in 0.01 })
        stage.character = character
        stage.idleMode = .stroll
        stage.companionActive = true
        #expect(stage.showsCompanion)
        stage.perform(.breakStart, character: character, edge: .top)
        #expect(stage.isPerforming)
        #expect(!stage.showsCompanion)
        try await Task.sleep(for: .seconds(0.6))
        #expect(!stage.isPerforming)
        #expect(stage.showsCompanion)
        #expect(stage.pillScale == 1)
    }

    @Test("A superseded performance cannot reveal the idle companion early")
    func supersededPerformance() async throws {
        let stage = CharacterStageModel(performanceDuration: { cue, _ in cue == .focusStart ? 0.01 : 0.3 })
        stage.idleMode = .calm
        stage.companionActive = true
        stage.perform(.focusStart, character: .hancock, edge: .top)
        try await Task.sleep(for: .seconds(0.05))
        stage.perform(.longBreak, character: .hancock, edge: .bottom)
        try await Task.sleep(for: .seconds(0.5))
        #expect(stage.isPerforming)
        #expect(!stage.showsCompanion)
        try await Task.sleep(for: .seconds(0.4))
        #expect(stage.showsCompanion)
    }
}
