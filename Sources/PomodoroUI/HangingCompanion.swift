import AppKit
import ImageIO
import PomodoroCore
import QuartzCore
import SwiftUI

/// Data-only authoring contract: three drawings, blink frames, grip anchors and
/// optical sizes. The right-hand climb is mirrored, rather than drawn again.
@MainActor
public final class CompanionKit {
    struct Manifest: Decodable {
        let version: Int
        let atlas: String
        let poses: [Pose]
        struct Pose: Decodable {
            let edge: StageEdge
            let open: [Double]
            let blink: [Double]
            let height: Double
            let grip: [Double]
            let sway: Double
        }
    }

    struct Artwork {
        let open: CGImage
        let blink: CGImage
        let size: CGSize
        let grip: CGPoint
        let sway: Double
    }

    private let poses: [StageEdge: Artwork]
    private init(poses: [StageEdge: Artwork]) { self.poses = poses }
    private static var loaded: [PomodoroCharacter: CompanionKit] = [:]

    public static func available(for character: PomodoroCharacter) -> Bool { load(for: character) != nil }

    static func load(for character: PomodoroCharacter) -> CompanionKit? {
        if let kit = loaded[character] { return kit }
        // Packaged apps carry the SwiftPM resource bundle in Contents/Resources.
        // SwiftPM development/test executables use their generated Bundle.module.
        let bundle = Bundle.main.url(forResource: "Pomodoro_PomodoroUI", withExtension: "bundle")
            .flatMap(Bundle.init(url:)) ?? Bundle.module
        guard let url = bundle.url(forResource: "\(character.rawValue)-kit", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 1,
              let atlasURL = bundle.url(forResource: manifest.atlas, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(atlasURL as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        var poses: [StageEdge: Artwork] = [:]
        for pose in manifest.poses {
            guard pose.open.count == 4, pose.blink.count == 4, pose.grip.count == 2,
                  pose.height.isFinite, (10...90).contains(pose.height),
                  pose.sway.isFinite, (0...2).contains(pose.sway),
                  pose.grip.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
            func crop(_ values: [Double]) -> CGImage? {
                guard values.allSatisfy(\.isFinite), values[2] > 0, values[3] > 0 else { return nil }
                let rect = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
                guard CGRect(x: 0, y: 0, width: atlas.width, height: atlas.height).contains(rect) else { return nil }
                return atlas.cropping(to: rect)
            }
            guard let open = crop(pose.open), let blink = crop(pose.blink),
                  open.width == blink.width, open.height == blink.height else { return nil }
            poses[pose.edge] = Artwork(open: open, blink: blink,
                size: CGSize(width: pose.height * Double(open.width) / Double(open.height), height: pose.height),
                grip: CGPoint(x: pose.grip[0], y: pose.grip[1]), sway: pose.sway)
        }
        guard poses[.top] != nil, poses[.bottom] != nil, poses[.leading] != nil else { return nil }
        let kit = CompanionKit(poses: poses)
        loaded[character] = kit
        return kit
    }

    func artwork(for edge: StageEdge) -> Artwork { poses[edge == .trailing ? .leading : edge]! }
    func metrics(for edge: StageEdge) -> CompanionDock.Metrics {
        let art = artwork(for: edge)
        return .init(size: art.size, grip: CGPoint(x: edge == .trailing ? 1 - art.grip.x : art.grip.x, y: art.grip.y))
    }
}

/// Coordinates use the same top-left origin as the pill and its screen bounds.
/// Move the contact along the rim before falling back to a different edge; never
/// clamp the character separately, which would detach its hands from the pill.
public enum CompanionDock {
    public struct Metrics: Equatable {
        public let size: CGSize
        public let grip: CGPoint
        public init(size: CGSize, grip: CGPoint) { self.size = size; self.grip = grip }
    }
    public struct Placement: Equatable {
        public let edge: StageEdge
        public let frame: CGRect
        public let contact: CGPoint
    }

    public static func resolve(preferred: StageEdge, position: Double, pill: CGRect, screen: CGRect,
                               metrics: (StageEdge) -> Metrics) -> Placement {
        let bounds = screen.isNull ? CGRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000) : screen
        let fraction = position.isFinite ? min(1, max(0, position)) : 0.5
        let remaining = StageEdge.allCases.filter { $0 != preferred && $0 != preferred.opposite }
        let order = [preferred, preferred.opposite] + remaining
        let candidates = order.map { edge in
            let art = metrics(edge)
            let contact: CGPoint
            switch edge {
            case .top, .bottom:
                let padding = min(pill.width / 2, pill.height / 2 + art.size.width / 2)
                let start = pill.minX + padding
                let end = pill.maxX - padding
                let wanted = start + (end - start) * fraction
                let low = max(start, bounds.minX + art.grip.x * art.size.width)
                let high = min(end, bounds.maxX - (1 - art.grip.x) * art.size.width)
                let x = low <= high ? min(high, max(low, wanted)) : wanted
                contact = CGPoint(x: x, y: edge == .top ? pill.minY : pill.maxY)
            case .leading, .trailing:
                // The hands and shoe follow the capsule's rounded shoulder.
                contact = CGPoint(x: edge == .leading ? pill.minX + 9 : pill.maxX - 9,
                                  y: pill.minY + 3 + fraction * 3)
            }
            return Placement(edge: edge,
                frame: CGRect(x: contact.x - art.grip.x * art.size.width,
                              y: contact.y - art.grip.y * art.size.height,
                              width: art.size.width, height: art.size.height), contact: contact)
        }
        return candidates.first { bounds.contains($0.frame.insetBy(dx: -1, dy: -1)) }
            ?? candidates.max { $0.frame.intersection(bounds).area < $1.frame.intersection(bounds).area }!
    }
}

private extension CGRect { var area: CGFloat { isNull ? 0 : width * height } }

/// The same native renderer powers both Settings' preview and the floating pill.
/// No per-frame SwiftUI updates or vector rasterization are needed.
public struct HangingCompanion: View {
    let character: PomodoroCharacter
    let mode: CharacterIdleMode
    let edge: StageEdge
    let position: Double
    let pill: CGRect
    let screen: CGRect
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(character: PomodoroCharacter, mode: CharacterIdleMode, edge: StageEdge,
                position: Double, pill: CGRect, screen: CGRect) {
        self.character = character; self.mode = mode; self.edge = edge
        self.position = position; self.pill = pill; self.screen = screen
    }

    public var body: some View {
        if let kit = CompanionKit.load(for: character) {
            HangingPlayer(kit: kit, mode: mode, edge: edge, position: position,
                          pill: pill, screen: screen, reduceMotion: reduceMotion)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct HangingPlayer: NSViewRepresentable {
    let kit: CompanionKit
    let mode: CharacterIdleMode
    let edge: StageEdge
    let position: Double
    let pill: CGRect
    let screen: CGRect
    let reduceMotion: Bool
    func makeNSView(context: Context) -> HangingSpriteView { HangingSpriteView() }
    func updateNSView(_ view: HangingSpriteView, context: Context) {
        view.configure(kit: kit, mode: mode, edge: edge, position: position,
                       pill: pill, screen: screen, reduceMotion: reduceMotion)
    }
    static func dismantleNSView(_ view: HangingSpriteView, coordinator: ()) { view.stop() }
}

@MainActor
final class HangingSpriteView: NSView {
    private let figure = CALayer()
    private let artwork = CALayer()
    private let occlusion = CAShapeLayer()
    private var kit: CompanionKit?
    private var mode: CharacterIdleMode = .off
    private var preference: StageEdge = .top
    private var position: Double = 0.5
    private var pill: CGRect = .zero
    private var screen: CGRect = .null
    private var reduceMotion = false
    private(set) var placement: CompanionDock.Placement?
    private var journey: Task<Void, Never>?
    private var transitioning = false

    override var isFlipped: Bool { true }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        artwork.contentsScale = 2
        artwork.contentsGravity = .resize
        figure.addSublayer(artwork)
        layer?.addSublayer(figure)
        occlusion.fillRule = .evenOdd
        layer?.mask = occlusion
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        updateMask()
    }

    private func updateMask() {
        // A 2-point lip lets fingers overlap the capsule while protecting all
        // controls and naturally occluding a tuck/pull behind the glass.
        let path = CGMutablePath()
        path.addRect(bounds)
        let inner = pill.insetBy(dx: 2, dy: 2)
        path.addRoundedRect(in: inner, cornerWidth: inner.height / 2, cornerHeight: inner.height / 2)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        occlusion.frame = bounds; occlusion.path = path
        CATransaction.commit()
    }

    func configure(kit: CompanionKit, mode: CharacterIdleMode, edge: StageEdge, position: Double,
                   pill: CGRect, screen: CGRect, reduceMotion: Bool) {
        let changed = self.kit !== kit || self.mode != mode || preference != edge
            || self.position != position || self.reduceMotion != reduceMotion
        let geometryChanged = self.pill != pill || self.screen != screen
        self.kit = kit; self.mode = mode; preference = edge; self.position = position
        self.pill = pill; self.screen = screen; self.reduceMotion = reduceMotion
        updateMask()
        if changed {
            stop()
            show(resolve(edge))
            startJourney(preview: true)
        } else if geometryChanged {
            if transitioning {
                stop()
                show(resolve(placement?.edge ?? preference))
                startJourney(preview: false)
            } else {
                let next = resolve(placement?.edge ?? preference)
                if next.edge != placement?.edge { show(next) } else { place(next) }
            }
        }
    }

    private func resolve(_ edge: StageEdge) -> CompanionDock.Placement {
        CompanionDock.resolve(preferred: edge, position: position, pill: pill, screen: screen) { kit!.metrics(for: $0) }
    }

    private func place(_ next: CompanionDock.Placement) {
        placement = next
        let art = kit!.metrics(for: next.edge)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        figure.bounds = CGRect(origin: .zero, size: art.size)
        figure.anchorPoint = art.grip
        figure.position = next.contact
        artwork.frame = figure.bounds
        artwork.transform = CATransform3DMakeScale(next.edge == .trailing ? -1 : 1, 1, 1)
        CATransaction.commit()
    }

    private func show(_ next: CompanionDock.Placement) {
        figure.removeAllAnimations()
        artwork.removeAllAnimations()
        place(next)
        let art = kit!.artwork(for: next.edge)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        artwork.contents = art.open
        figure.opacity = mode == .off ? 0 : 1
        figure.transform = CATransform3DIdentity
        CATransaction.commit()
        guard mode != .off, !reduceMotion else { return }

        let blink = CAKeyframeAnimation(keyPath: "contents")
        blink.values = [art.open, art.open, art.blink, art.blink, art.open, art.open]
        blink.keyTimes = [0, 0.68, 0.685, 0.71, 0.715, 1]
        blink.calculationMode = .discrete
        blink.duration = 8.5; blink.repeatCount = .infinity
        artwork.add(blink, forKey: "blink")

        let sway = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let angle = art.sway * .pi / 180
        sway.values = [0, -angle, 0, angle, 0]
        sway.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        sway.duration = 9; sway.repeatCount = .infinity
        sway.isAdditive = true
        sway.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
        figure.add(sway, forKey: "sway")

        let breath = CAKeyframeAnimation(keyPath: "transform.scale.y")
        breath.values = [1, 1.006, 1]
        breath.duration = 6; breath.repeatCount = .infinity
        breath.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 2)
        figure.add(breath, forKey: "breath")
    }

    func stop() {
        journey?.cancel(); journey = nil
        transitioning = false
        figure.removeAllAnimations()
        artwork.removeAllAnimations()
    }

    private func startJourney(preview: Bool) {
        guard mode == .stroll, !reduceMotion else { return }
        journey = Task { @MainActor [weak self] in
            var delay = preview ? 0.8 : 26.0
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                await self.relocate()
                delay = 26
            }
        }
    }

    private func relocate() async {
        guard let current = placement, mode == .stroll, !reduceMotion else { return }
        let cycle: [StageEdge] = [.top, .trailing, .bottom, .leading]
        let index = cycle.firstIndex(of: current.edge) ?? 0
        let next = (1..<cycle.count).map { resolve(cycle[(index + $0) % cycle.count]) }
            .first { $0.edge != current.edge }
        guard let next else { return } // Only one safe edge: keep resting there.
        transitioning = true
        figure.removeAnimation(forKey: "sway")
        figure.removeAnimation(forKey: "breath")
        tuck(edge: current.edge, appearing: false)
        do { try await Task.sleep(for: .seconds(0.55)) } catch { return }
        guard !Task.isCancelled else { return }
        show(next)
        tuck(edge: next.edge, appearing: true)
        do { try await Task.sleep(for: .seconds(0.7)) } catch { return }
        guard !Task.isCancelled else { return }
        transitioning = false
        show(next)
    }

    private func tuck(edge: StageEdge, appearing: Bool) {
        let normal = edge.inwardNormal
        let distance = max(figure.bounds.width, figure.bounds.height) + 6
        let translation = CAKeyframeAnimation(keyPath: "position")
        let contact = figure.position
        let hidden = CGPoint(x: contact.x - normal.x * distance, y: contact.y - normal.y * distance)
        let anticipation = CGPoint(x: contact.x + normal.x * 2, y: contact.y + normal.y * 2)
        translation.values = (appearing ? [hidden, anticipation, contact] : [contact, anticipation, hidden])
            .map { NSValue(point: $0) }
        translation.keyTimes = appearing ? [0, 0.78, 1] : [0, 0.22, 1]
        let squash = CAKeyframeAnimation(keyPath: "transform.scale.y")
        squash.values = appearing ? [0.82, 1.025, 1] : [1, 0.97, 0.82]
        squash.keyTimes = translation.keyTimes
        let tilt = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        tilt.values = appearing ? [0.09, -0.025, 0] : [0, -0.025, 0.09]
        tilt.keyTimes = translation.keyTimes; tilt.isAdditive = true
        let visibility = CAKeyframeAnimation(keyPath: "opacity")
        visibility.values = appearing ? [0, 1, 1] : [1, 1, 0]
        visibility.keyTimes = appearing ? [0, 0.35, 1] : [0, 0.6, 1]
        let group = CAAnimationGroup()
        group.animations = [translation, squash, tilt, visibility]
        group.duration = appearing ? 0.7 : 0.55
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.fillMode = .forwards; group.isRemovedOnCompletion = false
        figure.add(group, forKey: "relocate")
    }
}
