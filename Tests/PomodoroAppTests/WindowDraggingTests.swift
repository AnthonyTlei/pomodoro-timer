import AppKit
import PomodoroCore
import PomodoroUI
import SwiftUI
import Testing
@testable import Pomodoro

@Suite("Window dragging")
@MainActor
struct WindowDraggingTests {
    private func event(_ type: NSEvent.EventType, at point: NSPoint, window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1,
            clickCount: 1, pressure: 1
        ))
    }

    @Test("Dragging uses the event coordinates and stops when released")
    func eventCoordinatesMoveWindow() throws {
        _ = NSApplication.shared
        let screen = try #require(NSScreen.main)
        let window = NSWindow(
            contentRect: NSRect(x: screen.visibleFrame.midX - 150,
                                y: screen.visibleFrame.midY - 50, width: 300, height: 100),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        let view = WindowDragView(frame: NSRect(origin: .zero, size: window.frame.size))
        window.contentView = view
        let initial = window.frame.origin

        // The global cursor never moves: only the delivered events do. This also
        // exercises native drag events delivered by accessibility automation.
        view.mouseDown(with: try event(.leftMouseDown, at: NSPoint(x: 50, y: 25), window: window))
        view.mouseDragged(with: try event(.leftMouseDragged, at: NSPoint(x: 120, y: 55), window: window))
        #expect(Double(window.frame.minX) == Double(initial.x + 70))
        #expect(Double(window.frame.minY) == Double(initial.y + 30))

        // After the window moves, subsequent event positions are relative to its
        // new origin. Moving another 20/10 points must not count the first move twice.
        view.mouseDragged(with: try event(.leftMouseDragged, at: NSPoint(x: 70, y: 35), window: window))
        #expect(Double(window.frame.minX) == Double(initial.x + 90))
        #expect(Double(window.frame.minY) == Double(initial.y + 40))

        view.mouseUp(with: try event(.leftMouseUp, at: NSPoint(x: 50, y: 25), window: window))
        let released = window.frame
        view.mouseDragged(with: try event(.leftMouseDragged, at: NSPoint(x: 200, y: 80), window: window))
        #expect(window.frame == released)
    }

    @Test("Only the readout routes to the drag surface")
    func dragRoutingPreservesControlsAndMargins() {
        _ = NSApplication.shared
        let host = FloatingBarHostingView(rootView: Color.clear)
        host.frame = NSRect(origin: .zero, size: FloatingBar.panelSize)
        host.geometry = BarGeometry()
        let pill = FloatingBar.pillFrame

        #expect(host.hitTest(NSPoint(x: pill.minX + 50, y: pill.midY)) is WindowDragView)
        for x in [FloatingBar.Metrics.primaryX + 14,
                  FloatingBar.Metrics.secondaryX(0) + 13,
                  FloatingBar.Metrics.secondaryX(1) + 13] {
            #expect(!(host.hitTest(NSPoint(x: pill.minX + x, y: pill.midY)) is WindowDragView))
        }
        #expect(host.hitTest(NSPoint(x: 5, y: 5)) == nil)
        host.geometry?.hitFrame = FloatingBar.compactFrame
        #expect(host.hitTest(NSPoint(x: pill.maxX - 5, y: pill.midY)) == nil)
        #expect(host.hitTest(NSPoint(x: pill.minX + 50, y: pill.midY)) is WindowDragView)
        #expect(!(host.hitTest(NSPoint(x: pill.minX + FloatingBar.Metrics.primaryX + 14,
                                     y: pill.midY)) is WindowDragView))
    }

    @Test("A mounted hanging companion preserves native drag routing")
    func hangingCompanionDrag() throws {
        _ = NSApplication.shared
        let screen = try #require(NSScreen.main)
        let pill = FloatingBar.pillFrame
        let host = FloatingBarHostingView(rootView: ZStack {
            Color.clear
            HangingCompanion(character: .hancock, mode: .calm, edge: .top, position: 0.5,
                             pill: pill, screen: .null)
        })
        host.geometry = BarGeometry()
        let window = NSWindow(contentRect: CGRect(x: screen.visibleFrame.midX - 228,
            y: screen.visibleFrame.midY - 133, width: FloatingBar.panelSize.width,
            height: FloatingBar.panelSize.height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let contact = CGPoint(x: pill.minX + 65, y: pill.midY)
        let drag = try #require(host.hitTest(contact) as? WindowDragView)
        let origin = window.frame.origin
        drag.mouseDown(with: try event(.leftMouseDown, at: contact, window: window))
        drag.mouseDragged(with: try event(.leftMouseDragged,
            at: CGPoint(x: contact.x + 25, y: contact.y + 20), window: window))
        #expect(window.frame.minX == origin.x + 25)
        #expect(window.frame.minY == origin.y + 20)
        #expect(host.hitTest(CGPoint(x: pill.midX, y: pill.minY - 20)) == nil)
        drag.mouseUp(with: try event(.leftMouseUp, at: contact, window: window))
    }
}
