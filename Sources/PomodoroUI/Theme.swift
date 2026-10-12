import AppKit
import Observation
import PomodoroCore
import SwiftUI

/// Semantic colors shared by every app surface and both widget sizes.
public enum Theme {
    public static func tint(for phase: Phase, in theme: ThemeConfiguration = .init()) -> Color {
        theme.palette[phase].tint.color
    }
    public static func highlight(for phase: Phase, in theme: ThemeConfiguration = .init()) -> Color {
        theme.palette[phase].highlight.color
    }
    public static func backdrop(for phase: Phase, in theme: ThemeConfiguration = .init()) -> LinearGradient {
        let base = theme.palette.surface ?? theme.palette[phase].tint
        let light = theme.palette.surface.map { $0.mixed(with: ThemeColor(0xFFFFFF), amount: 0.28) }
            ?? theme.palette[phase].highlight
        let strength = theme.surfaceStrength
        return LinearGradient(
            colors: [base.color.opacity(0.34 * strength), light.color.opacity(0.10 * strength), base.color.opacity(0.04 * strength)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    public static func legibleTint(for phase: Phase, in theme: ThemeConfiguration, scheme: ColorScheme) -> Color {
        theme.palette[phase].tint.legible(on: ThemeColor(scheme == .dark ? 0x242424 : 0xF5F5F5)).color
    }
    public static func ink(for phase: Phase, in theme: ThemeConfiguration) -> Color {
        theme.palette[phase].tint.contrastingInk.color
    }
    /// Labels spanning a phase gradient need contrast against both ends.
    public static func gradientInk(for phase: Phase, in theme: ThemeConfiguration) -> Color {
        let colors = theme.palette[phase]
        let white = ThemeColor(0xFFFFFF)
        let black = ThemeColor(0)
        let whiteContrast = min(colors.tint.contrast(with: white), colors.highlight.contrast(with: white))
        let blackContrast = min(colors.tint.contrast(with: black), colors.highlight.contrast(with: black))
        return (whiteContrast >= blackContrast ? white : black).color
    }
    public static func bloom(for phase: Phase, in theme: ThemeConfiguration, highlighted: Bool = true) -> Color {
        let phaseColor = highlighted ? theme.palette[phase].highlight : theme.palette[phase].tint
        return (theme.palette.surface ?? phaseColor).color.opacity(0.30 * theme.surfaceStrength)
    }
    public static func symbol(for phase: Phase) -> String {
        switch phase {
        case .focus: "timer"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "figure.walk"
        }
    }
}

public extension ThemeColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

private struct PomodoroThemeKey: EnvironmentKey {
    static let defaultValue = ThemeConfiguration()
}
public extension EnvironmentValues {
    var pomodoroTheme: ThemeConfiguration {
        get { self[PomodoroThemeKey.self] }
        set { self[PomodoroThemeKey.self] = newValue }
    }
}
public extension ThemeAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
public extension View {
    /// Windows resolve System independently of their last override. Widgets and
    /// offscreen renderers inherit their host's scheme and set only the environment.
    func pomodoroAppearance(_ theme: ThemeConfiguration, inWindow: Bool = true) -> some View {
        modifier(PomodoroAppearanceModifier(theme: theme, inWindow: inWindow))
    }
}
private struct PomodoroAppearanceModifier: ViewModifier {
    let theme: ThemeConfiguration
    let inWindow: Bool
    @Environment(\.colorScheme) private var inheritedScheme
    @ViewBuilder
    func body(content: Content) -> some View {
        let systemScheme = inWindow ? ApplicationAppearanceState.shared.scheme : inheritedScheme
        let scheme = theme.appearance.colorScheme ?? systemScheme
        if inWindow {
            // A hosting window's inherited colorScheme can still be the previous
            // override. Resolve System from NSApplication rather than feeding
            // that stale window value back into SwiftUI's environment.
            content.environment(\.pomodoroTheme, theme)
                .environment(\.colorScheme, scheme)
                .preferredColorScheme(theme.appearance.colorScheme)
                .tint(Theme.legibleTint(for: .focus, in: theme, scheme: scheme))
        } else {
            content.environment(\.pomodoroTheme, theme)
                .environment(\.colorScheme, scheme)
                .tint(Theme.legibleTint(for: .focus, in: theme, scheme: scheme))
        }
    }
}

/// NSApplication's effective appearance follows the system independently of any
/// individual window override. One observer also keeps already-open windows live
/// when macOS changes appearance; it never changes the application's appearance.
@Observable
@MainActor
private final class ApplicationAppearanceState {
    static let shared = ApplicationAppearanceState()
    private(set) var scheme: ColorScheme
    @ObservationIgnored private var observation: NSKeyValueObservation?

    private init() {
        scheme = Self.resolve(NSApplication.shared.effectiveAppearance)
        observation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.scheme = Self.resolve(NSApplication.shared.effectiveAppearance)
            }
        }
    }

    private static func resolve(_ appearance: NSAppearance) -> ColorScheme {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }
}

/// Observes preferences at each hosting boundary, keeping open windows in sync.
public struct ThemedView<Content: View>: View {
    private let settings: PomodoroSettings
    private let content: Content
    public init(settings: PomodoroSettings, @ViewBuilder content: () -> Content) {
        self.settings = settings
        self.content = content()
    }
    public var body: some View { content.pomodoroAppearance(settings.theme) }
}

// MARK: - Liquid Glass

/// Applies the macOS 26 Liquid Glass material, falling back to the older blurred
/// material on earlier systems.
///
/// The fallback is not a lookalike — `.regularMaterial` is the previous generation's
/// vibrancy, which is the correct native answer on those systems. Chasing the glass
/// look with hand-rolled gradients would age badly and look wrong against real
/// system chrome.
public struct GlassPanel<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    public func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(
                    shape.stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

public extension View {
    /// Liquid Glass on macOS 26, `.regularMaterial` before it.
    func glassPanel(
        in shape: some Shape = Capsule(),
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassPanel(shape: shape, tint: tint, interactive: interactive))
    }

    /// Groups nearby glass elements so they blend and refract as one surface
    /// rather than as separate stacked panes. A no-op before macOS 26.
    @ViewBuilder
    func glassGroup(spacing: CGFloat = 12) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

public extension View {
    /// Tags a glass element so it morphs into its neighbours when they appear and
    /// disappear, instead of popping. The whole point of grouping glass — without
    /// an identity, two controls fading in look like two separate panes.
    /// A no-op before macOS 26.
    @ViewBuilder
    func glassMorphID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

/// The Liquid Glass button style, degrading to a plain bordered button.
///
/// The press is a scale *and* a dim, not a dim alone. Dimming on its own says the
/// control noticed; giving under the finger says it is a physical thing being pressed,
/// and it is the difference between a button that acknowledges a click and one that
/// feels connected to it. 0.94 is roughly 1.6pt on a 26pt control — small, but well
/// above the point where a change stops being visible.
///
/// It fires on press rather than on release, which `ButtonStyle` gives for free and is
/// the whole reason to use one: feedback that waits for the mouse-up arrives after the
/// user has already stopped asking a question.
public struct AdaptiveGlassButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1, anchor: .center)
            .opacity(configuration.isPressed ? 0.7 : 1)
            // A stronger ease-out than the built-in, which is weak enough that a
            // 130ms move reads as linear. Nothing here eases *in*: the moment the
            // user is watching is the first frame after the click, and starting slow
            // spends it.
            .animation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.13), value: configuration.isPressed)
    }
}

public extension View {
    /// A circular control that is glass on macOS 26 and a subtle material before it.
    ///
    /// Note the deliberate absence of a tint: a tinted Liquid Glass circle renders
    /// close to opaque, which on a 26pt control reads as a solid coloured blob
    /// rather than a button. Colour belongs in the glyph, where it stays legible.
    func glassControl(size: CGFloat = 30) -> some View {
        frame(width: size, height: size)
            .glassPanel(in: Circle(), interactive: true)
            // The glass is a background, so without an explicit content shape only
            // the glyph itself takes the click — the ring around it looks like part
            // of the button but isn't.
            .contentShape(Circle())
    }
}
