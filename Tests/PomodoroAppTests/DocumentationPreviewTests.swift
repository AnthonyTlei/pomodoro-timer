import AppKit
import PomodoroCore
import PomodoroUI
import SwiftUI
import Testing
@testable import Pomodoro

/// Optional documentation capture host. All preferences and timer files are
/// scratch fixtures; the production timer and widget are never used.
@Suite("Documentation previews", .serialized)
@MainActor
struct DocumentationPreviewTests {
    @Test("Open native app views for README capture when explicitly requested")
    func nativeReview() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let scene = environment["POMODORO_README_SCENE"] else { return }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let settings = PomodoroSettings(defaults: makeAppTestDefaults())
        settings.character = .hancock
        settings.characterIdleMode = .calm
        var theme = settings.theme
        theme.preset = .hancock; theme.appearance = .dark
        settings.theme = theme
        let delegate = DocumentationWindowDelegate()
        let window: NSWindow
        if scene == "bar" {
            let controller = TimerController(settings: settings, stats: StatsStore(fileURL: makeScratchStatsURL()),
                                             shared: makeAppTestSharedStore())
            let bar = FloatingBar(controller: controller, settings: settings)
            // A neutral canvas makes the glass readable in both GitHub appearances.
            bar.backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 1)
            bar.isOpaque = true
            bar.stage.character = settings.character
            bar.setCompanionVisible(true)
            settings.onFloatingBarChange = { [weak bar, weak settings] in
                guard let bar, let settings else { return }
                bar.setOrientation(settings.pillOrientation)
                if !settings.showFloatingBar { DocumentationWindowDelegate.stop() }
            }
            bar.onOpenSettings = { DocumentationWindowDelegate.stop() }
            window = bar
        } else {
            let host = NSHostingController(rootView: Group {
                if scene == "appearance" {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Appearance").font(.system(size: 16, weight: .semibold))
                        AppearanceSettingsView(settings: settings)
                    }
                    .padding(20).frame(width: 440)
                    .background(Color(white: 0.09))
                    .pomodoroAppearance(settings.theme, inWindow: true)
                } else {
                    DocumentationCompanions()
                }
            })
            window = NSWindow(contentViewController: host)
            window.title = scene == "appearance" ? "Pomodoro · Appearance" : "Pomodoro · Companions"
            window.styleMask = [.titled, .closable]
            window.setContentSize(scene == "appearance" ? CGSize(width: 440, height: 640) : CGSize(width: 1080, height: 430))
        }
        window.isReleasedWhenClosed = false
        window.delegate = delegate
        window.center(); window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        let timeout = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { _ in
            MainActor.assumeIsolated { DocumentationWindowDelegate.stop() }
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            RunLoop.main.perform {
                MainActor.assumeIsolated {
                    withExtendedLifetime(delegate) { app.run() }
                    continuation.resume()
                }
            }
        }
        timeout.invalidate()
        settings.onFloatingBarChange = nil
        window.close()
    }
}

private struct DocumentationCompanions: View {
    @State private var mode = CharacterIdleMode.calm
    private let roster = PomodoroCharacter.allCases.filter { $0 != .none }
    var body: some View {
        VStack(spacing: 0) {
            Picker("Companions", selection: $mode) {
                Text("Idle").tag(CharacterIdleMode.calm)
                Text("Lively").tag(CharacterIdleMode.stroll)
            }.pickerStyle(.segmented).frame(width: 240).padding(.top, 16)
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(Array(roster[(row * 3)..<(row * 3 + 3)])) { character in
                        cell(character)
                    }
                }
            }
        }
        .frame(width: 1080, height: 430)
        .background(Color(white: 0.09))
        .preferredColorScheme(.dark)
    }
    private func cell(_ character: PomodoroCharacter) -> some View {
        var theme = ThemeConfiguration()
        theme.preset = ThemePreset.matching(character) ?? .classic
        theme.appearance = .dark
        let pill = CGRect(x: 62, y: 60, width: 236, height: 46)
        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ThemeTimerPreview().position(x: pill.midX, y: pill.midY)
                HangingCompanion(character: character, mode: mode, edge: .top, position: 0.5,
                    pill: pill, screen: CGRect(x: 0, y: 0, width: 360, height: 174))
            }.frame(width: 360, height: 174)
            Text(character.displayName).font(.system(size: 12, weight: .semibold)).padding(.bottom, 16)
        }.pomodoroAppearance(theme, inWindow: false)
    }
}

@MainActor
private final class DocumentationWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { Self.stop() }
    static func stop() {
        let app = NSApplication.shared
        app.stop(nil)
        if let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
            app.postEvent(event, atStart: true)
        }
    }
}
