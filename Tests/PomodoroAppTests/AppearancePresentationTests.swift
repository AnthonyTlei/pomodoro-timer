import AppKit
import PomodoroCore
import PomodoroUI
import SwiftUI
import Testing
@testable import Pomodoro

@Suite("Appearance presentation")
@MainActor
struct AppearancePresentationTests {
    @Test("Inspect the native Settings window locally when requested")
    func nativeReview() {
        guard ProcessInfo.processInfo.environment["POMODORO_THEME_NATIVE_REVIEW"] == "1" else { return }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let settings = PomodoroSettings(defaults: makeAppTestDefaults())
        settings.character = .hancock
        let host = NSHostingController(rootView: ThemedView(settings: settings) {
            SettingsView(settings: settings, onChange: {}, onPreview: { _ in })
        })
        let window = NSWindow(contentViewController: host)
        window.title = "Pomodoro Theme Review"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        let delegate = ReviewWindowDelegate()
        window.delegate = delegate
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        // A separate test host uses scratch preferences; the user's running timer
        // and widget are untouched. Closing the review window ends the test.
        let timeout = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { _ in
            MainActor.assumeIsolated { ReviewWindowDelegate.stopReview() }
        }
        withExtendedLifetime(delegate) { app.run() }
        timeout.invalidate()
        window.close()
    }

    @Test("Export the actual appearance section for local visual review when requested")
    func reviewPanel() throws {
        guard let directory = ProcessInfo.processInfo.environment["POMODORO_THEME_PREVIEW"] else { return }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for appearance in [ThemeAppearance.light, .dark] {
            let settings = PomodoroSettings(defaults: makeAppTestDefaults())
            settings.character = .hancock
            var theme = ThemeConfiguration()
            theme.preset = .hancock
            theme.appearance = appearance
            settings.theme = theme
            let renderer = ImageRenderer(content:
                ThemedView(settings: settings) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Appearance").font(.system(size: 16, weight: .semibold))
                        AppearanceSettingsView(settings: settings)
                    }
                    .padding(20)
                    .frame(width: 440)
                    .background(appearance == .dark ? Color(white: 0.14) : Color(white: 0.96))
                }
            )
            renderer.scale = 2
            let image = try #require(renderer.nsImage)
            let tiff = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("appearance-\(appearance.rawValue).png"))
        }
    }
}

@MainActor
private final class ReviewWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { Self.stopReview() }
    static func stopReview() {
        let app = NSApplication.shared
        app.stop(nil)
        if let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero,
                                          modifierFlags: [], timestamp: 0, windowNumber: 0,
                                          context: nil, subtype: 0, data1: 0, data2: 0) {
            app.postEvent(event, atStart: true)
        }
    }
}
