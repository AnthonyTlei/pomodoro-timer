import AppKit
import PomodoroCore
import QuartzCore
import SwiftUI
import Testing
@testable import PomodoroUI

@Suite("Hanging companion", .serialized)
@MainActor
struct HangingCompanionTests {
    @Test("Bundled Boa kit has matched optical sizes, transparency, and blink frames")
    func artwork() throws {
        let kit = try #require(CompanionKit.load(for: .hancock))
        var areas: [Double] = []
        for edge in [StageEdge.top, .bottom, .leading] {
            let art = kit.artwork(for: edge)
            let bitmap = NSBitmapImageRep(cgImage: art.open)
            var alpha = 0.0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    alpha += Double(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0)
                }
            }
            let scale = art.size.height / Double(art.open.height)
            areas.append(alpha * scale * scale)
            #expect(alpha > 10_000)
            #expect(bitmap.colorAt(x: 0, y: 0)!.alphaComponent < 0.05)
            #expect(art.open.dataProvider?.data != art.blink.dataProvider?.data)
        }
        #expect(areas.max()! / areas.min()! < 1.15, "A pose changes Boa's visual weight: \(areas)")
        #expect(CompanionKit.load(for: .samurai) == nil) // Preserve existing fallback until its art is approved.
    }

    @Test("Every edge stays attached and falls back safely at screen boundaries")
    func layout() throws {
        let kit = try #require(CompanionKit.load(for: .hancock))
        let screen = CGRect(x: -1440, y: -900, width: 1440, height: 900)
        for width in [236.0, 172] {
            for origin in [CGPoint(x: -900, y: -500), CGPoint(x: -1439, y: -899),
                           CGPoint(x: -width - 1, y: -899), CGPoint(x: -1439, y: -47),
                           CGPoint(x: -width - 1, y: -47)] {
                let pill = CGRect(origin: origin, size: CGSize(width: width, height: 46))
                for edge in StageEdge.allCases {
                    for position in [0.0, 0.5, 1] {
                        let placed = CompanionDock.resolve(preferred: edge, position: position,
                            pill: pill, screen: screen) { kit.metrics(for: $0) }
                        #expect(screen.contains(placed.frame))
                        let m = kit.metrics(for: placed.edge)
                        #expect(abs(placed.frame.minX + m.grip.x * m.size.width - placed.contact.x) < 0.001)
                        #expect(abs(placed.frame.minY + m.grip.y * m.size.height - placed.contact.y) < 0.001)
                        if placed.edge == .top { #expect(placed.contact.y == pill.minY) }
                        if placed.edge == .bottom { #expect(placed.contact.y == pill.maxY) }
                    }
                }
            }
        }
    }

    @Test("Native layer does not intercept dragging; Idle and Reduce Motion stay parked")
    func stationary() async throws {
        let kit = try #require(CompanionKit.load(for: .hancock))
        let view = HangingSpriteView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        let pill = CGRect(x: 82, y: 60, width: 236, height: 46)
        view.configure(kit: kit, mode: .calm, edge: .bottom, position: 0.5,
                       pill: pill, screen: view.bounds, reduceMotion: false)
        let initial = view.placement
        #expect(view.hitTest(CGPoint(x: 200, y: 120)) == nil)
        try await Task.sleep(for: .seconds(1.5))
        #expect(view.placement == initial)
        view.configure(kit: kit, mode: .stroll, edge: .bottom, position: 0.5,
                       pill: pill, screen: view.bounds, reduceMotion: true)
        try await Task.sleep(for: .seconds(1.5))
        #expect(view.placement == initial)
        #expect(view.layer?.sublayers?.first?.animationKeys()?.isEmpty != false)
        view.stop()
    }

    @Test("Lively demonstrates a relocation immediately and cancelled work stays cancelled")
    func lively() async throws {
        let kit = try #require(CompanionKit.load(for: .hancock))
        let view = HangingSpriteView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        let pill = CGRect(x: 82, y: 60, width: 236, height: 46)
        view.configure(kit: kit, mode: .stroll, edge: .top, position: 0.5,
                       pill: pill, screen: view.bounds, reduceMotion: false)
        try await Task.sleep(for: .seconds(1.6))
        #expect(view.placement?.edge == .trailing)
        // Changing the preference during settling cancels the old transition.
        view.configure(kit: kit, mode: .calm, edge: .leading, position: 0.2,
                       pill: pill, screen: view.bounds, reduceMotion: false)
        try await Task.sleep(for: .seconds(0.8))
        #expect(view.placement?.edge == .leading)
        view.stop()
    }

    @Test("Inspect the native hanging renderer locally when requested")
    func nativeReview() throws {
        guard ProcessInfo.processInfo.environment["POMODORO_HANGING_REVIEW"] == "1" else { return }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let host = NSHostingController(rootView: HangingReview())
        let window = NSWindow(contentViewController: host)
        window.title = "Boa Companion Review"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center(); window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)
        let timeout = Timer.scheduledTimer(withTimeInterval: 110, repeats: false) { _ in
            MainActor.assumeIsolated {
                app.stop(nil)
                app.postEvent(NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [],
                    timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!, atStart: true)
            }
        }
        app.run(); timeout.invalidate(); window.close()
    }
}

private struct HangingReview: View {
    @State private var mode = CharacterIdleMode.calm
    var body: some View {
        VStack(spacing: 8) {
            Picker("Mode", selection: $mode) {
                Text("Idle").tag(CharacterIdleMode.calm)
                Text("Lively").tag(CharacterIdleMode.stroll)
            }.pickerStyle(.segmented).frame(width: 250)
            ForEach(StageEdge.allCases, id: \.self) { edge in
                ZStack(alignment: .topLeading) {
                    ThemeTimerPreview().position(x: 200, y: 70)
                    HangingCompanion(character: .hancock, mode: mode, edge: edge, position: 0.5,
                        pill: CGRect(x: 82, y: 47, width: 236, height: 46),
                        screen: CGRect(x: 0, y: 0, width: 400, height: 160))
                }.frame(width: 400, height: 160)
            }
        }.padding(18).background(Color(white: 0.14))
            .pomodoroAppearance(ThemeConfiguration(), inWindow: true)
    }
}
