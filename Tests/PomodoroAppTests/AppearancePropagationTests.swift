import AppKit
import PomodoroCore
import PomodoroUI
import SwiftUI
import Testing

@Suite("Native appearance propagation", .serialized)
@MainActor
struct AppearancePropagationTests {
    @Test("Returning to System releases the previous override in native windows and SwiftUI",
          arguments: [ColorScheme.light, .dark])
    func transitions(system: ColorScheme) async throws {
        let app = NSApplication.shared
        let originalAppearance = app.appearance
        app.appearance = NSAppearance(named: system == .dark ? .darkAqua : .aqua)
        defer { app.appearance = originalAppearance }

        let settings = PomodoroSettings(defaults: makeAppTestDefaults())
        let observation = SchemeObservation()
        let host = NSHostingController(rootView: ThemedView(settings: settings) {
            SchemeProbe { observation.scheme = $0; observation.identities.insert($1) }
        })
        let window = NSWindow(contentViewController: host)
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFront(nil)
        defer { window.close() }

        for source in ThemeAppearance.allCases {
            for destination in ThemeAppearance.allCases where destination != source {
                for mode in [source, destination] {
                    var theme = settings.theme
                    theme.appearance = mode
                    settings.theme = theme
                    // Allow the normal hosting update, but not a later interaction
                    // or arbitrary repaint to rescue stale appearance state.
                    try await Task.sleep(for: .milliseconds(100))
                    let expected = mode.colorScheme ?? system
                    let native = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
                    #expect(native == (expected == .dark ? .darkAqua : .aqua), "\(source) → \(destination), system \(system)")
                    #expect(observation.scheme == expected, "SwiftUI retained a previous mode for \(source) → \(destination), system \(system)")
                    let controls = descendants(of: host.view).compactMap { $0 as? NSSegmentedControl }
                    #expect(!controls.isEmpty, "The regression must exercise a real native segmented control")
                    for control in controls {
                        #expect(control.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == native,
                                "Native control retained the previous appearance")
                    }
                }
            }
        }
        #expect(observation.identities.count == 1, "Appearance changes must preserve existing view state")
    }

    @Test("Open System windows follow application appearance changes while explicit modes stay fixed")
    func systemChanges() async throws {
        let app = NSApplication.shared
        let originalAppearance = app.appearance
        defer { app.appearance = originalAppearance }
        let settings = PomodoroSettings(defaults: makeAppTestDefaults())
        let observation = SchemeObservation()
        let host = NSHostingController(rootView: ThemedView(settings: settings) {
            SchemeProbe { observation.scheme = $0; observation.identities.insert($1) }
        })
        let window = NSWindow(contentViewController: host)
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFront(nil)
        defer { window.close() }
        for mode in ThemeAppearance.allCases {
            var theme = settings.theme
            theme.appearance = mode
            settings.theme = theme
            for system in [ColorScheme.light, .dark, .light] {
                app.appearance = NSAppearance(named: system == .dark ? .darkAqua : .aqua)
                try await Task.sleep(for: .milliseconds(100))
                let expected = mode.colorScheme ?? system
                #expect(observation.scheme == expected)
                #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == (expected == .dark ? .darkAqua : .aqua))
            }
        }
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}

@MainActor
private final class SchemeObservation {
    var scheme: ColorScheme?
    var identities = Set<UUID>()
}

private struct SchemeProbe: View {
    let report: (ColorScheme, UUID) -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var identity = UUID()
    var body: some View {
        VStack {
            Text("Appearance probe")
            Picker("Mode", selection: .constant(0)) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .onChange(of: scheme, initial: true) { _, value in report(value, identity) }
    }
}
