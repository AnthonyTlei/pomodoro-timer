import Foundation
import Testing
@testable import PomodoroCore

@Suite("Settings")
struct SettingsTests {

    @Test("Defaults match the classic 25/5/15/4 pomodoro")
    func defaults() {
        let settings = PomodoroSettings(defaults: makeDefaults())
        #expect(settings.focusMinutes == 25)
        #expect(settings.shortBreakMinutes == 5)
        #expect(settings.longBreakMinutes == 15)
        #expect(settings.pomodorosUntilLongBreak == 4)
        #expect(settings.autoStartBreaks)
        #expect(!settings.autoStartFocus)
        #expect(settings.controlMusic)
    }

    @Test("Durations are clamped, so a stray 0 or 9999 can't break the timer")
    func clamping() {
        let settings = PomodoroSettings(defaults: makeDefaults())

        settings.focusMinutes = 0
        #expect(settings.focusMinutes == 1)

        settings.focusMinutes = 9999
        #expect(settings.focusMinutes == 240)

        settings.pomodorosUntilLongBreak = 0
        #expect(settings.pomodorosUntilLongBreak == 1)

        settings.pomodorosUntilLongBreak = 50
        #expect(settings.pomodorosUntilLongBreak == 12)
    }

    @Test("Values round-trip through UserDefaults")
    func roundTrip() {
        let defaults = makeDefaults()
        let first = PomodoroSettings(defaults: defaults)
        first.focusMinutes = 45
        first.autoStartFocus = true
        first.chimeEnabled = false

        let second = PomodoroSettings(defaults: defaults)
        #expect(second.focusMinutes == 45)
        #expect(second.autoStartFocus)
        #expect(!second.chimeEnabled)
    }

    @Test("Floating bar position is nil until it's been dragged")
    func floatingBarPosition() {
        let settings = PomodoroSettings(defaults: makeDefaults())
        #expect(settings.floatingBarOrigin == nil)

        settings.floatingBarOrigin = (x: 120.5, y: 640)
        let stored = settings.floatingBarOrigin
        #expect(stored?.x == 120.5)
        #expect(stored?.y == 640)
    }

    @Test("The compact bar is off until it's asked for, then round-trips")
    func compactFloatingBarIsOptIn() {
        let defaults = makeDefaults()
        let settings = PomodoroSettings(defaults: defaults)
        #expect(!settings.compactFloatingBar)

        settings.compactFloatingBar = true
        #expect(PomodoroSettings(defaults: defaults).compactFloatingBar)
    }

    @Test("onChange fires on every write, so views can redraw")
    func changeCallback() {
        let settings = PomodoroSettings(defaults: makeDefaults())
        var calls = 0
        settings.onChange = { calls += 1 }

        settings.focusMinutes = 30
        settings.autoStartBreaks = false

        #expect(calls == 2)
    }

    @Test("The idle companion is opt-in, persists, and tolerates future values")
    func idleCompanionSettings() {
        let defaults = makeDefaults()
        let first = PomodoroSettings(defaults: defaults)
        #expect(first.characterIdleMode == .off)
        var calls = 0
        first.onChange = { calls += 1 }
        for mode in CharacterIdleMode.allCases {
            first.characterIdleMode = mode
            #expect(PomodoroSettings(defaults: defaults).characterIdleMode == mode)
        }
        #expect(calls == 3)
        defaults.set("future-mode", forKey: PomodoroSettings.Key.characterIdleMode.rawValue)
        #expect(PomodoroSettings(defaults: defaults).characterIdleMode == .off)
    }

    @Test("Hanging placement persists without changing legacy mode values")
    func hangingPlacement() {
        let defaults = makeDefaults()
        let settings = PomodoroSettings(defaults: defaults)
        #expect(settings.characterCompanionEdge == .top)
        #expect(settings.characterCompanionPosition == 0.5)
        settings.characterIdleMode = .calm
        settings.characterCompanionEdge = .trailing
        settings.characterCompanionPosition = 0.75
        let restored = PomodoroSettings(defaults: defaults)
        #expect(restored.characterCompanionEdge == .trailing)
        #expect(restored.characterCompanionPosition == 0.75)
        #expect(defaults.string(forKey: PomodoroSettings.Key.characterIdleMode.rawValue) == "calm")
        settings.characterCompanionPosition = .nan
        #expect(settings.characterCompanionPosition == 0.5)
        defaults.set("future-edge", forKey: PomodoroSettings.Key.characterCompanionEdge.rawValue)
        defaults.set(2.0, forKey: PomodoroSettings.Key.characterCompanionPosition.rawValue)
        #expect(settings.characterCompanionEdge == .top)
        #expect(settings.characterCompanionPosition == 1)
    }

    @Test("Companion presentation edits bypass duration-settings callbacks")
    func companionCallbacks() {
        let settings = PomodoroSettings(defaults: makeDefaults())
        var general = 0, companion = 0
        settings.onChange = { general += 1 }
        settings.onCompanionChange = { companion += 1 }
        settings.characterIdleMode = .stroll
        settings.characterCompanionEdge = .bottom
        settings.characterCompanionPosition = 0.8
        #expect(companion == 3)
        #expect(general == 0)
        settings.focusMinutes = 35
        #expect(general == 1)
    }
}
