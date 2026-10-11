import Foundation
import Testing
@testable import Pomodoro
@testable import PomodoroCore

@Suite("Appearance lifecycle")
@MainActor
struct AppearanceLifecycleTests {
    @Test("Changing appearance preserves a paused or running session and emits no music signal")
    func preservesSession() {
        let settings = PomodoroSettings(defaults: makeAppTestDefaults())
        let controller = TimerController(settings: settings, stats: StatsStore(fileURL: makeScratchStatsURL()),
                                         shared: makeAppTestSharedStore())
        var signals: [Bool] = []
        controller.onFocusRunningChanged = { signals.append($0) }
        settings.onAppearanceChange = { controller.appearanceChanged() }
        controller.start()
        controller.pause()
        let pausedRemaining = controller.remainingSeconds
        let phaseLength = controller.totalSeconds
        // A future duration has been edited outside the live controller. A theme
        // update must not apply that duration to the existing paused session.
        settings.focusMinutes = 45
        var theme = settings.theme
        theme.preset = .ninja
        settings.theme = theme
        #expect(!controller.isRunning && controller.remainingSeconds == pausedRemaining)
        #expect(controller.totalSeconds == phaseLength)
        #expect(signals == [true, false])
        controller.start()
        theme.preset = .rabbit
        settings.theme = theme
        #expect(controller.isRunning && controller.remainingSeconds == pausedRemaining)
        #expect(controller.totalSeconds == phaseLength)
        #expect(signals == [true, false, true])
        controller.pause()
    }

    @Test("Rapid theme edits reach the widget in order without another timer transition")
    func mirrorsLatestAppearance() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pomodoro-theme-bridge-\(UUID().uuidString)", isDirectory: true)
        let store = SharedStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = PomodoroSettings(defaults: makeAppTestDefaults())
        let controller = TimerController(settings: settings, stats: StatsStore(fileURL: makeScratchStatsURL()), shared: store)
        settings.onAppearanceChange = { controller.appearanceChanged() }
        for preset in ThemePreset.allCases {
            var theme = settings.theme
            theme.preset = preset
            settings.theme = theme
        }
        var latest = settings.theme
        latest.preset = .hancock
        latest.appearance = .dark
        latest.surfaceStrength = 0.37
        settings.theme = latest
        for _ in 0..<100 {
            if store.readSnapshot()?.theme == latest { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let snapshot = try #require(store.readSnapshot())
        #expect(snapshot.theme == latest)
        #expect(snapshot.remainingSeconds == controller.remainingSeconds)
        #expect(!snapshot.isRunning && snapshot.phase == .focus)
        #expect(!store.isShared)
    }
}
