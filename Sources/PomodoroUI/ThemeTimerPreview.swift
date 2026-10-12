import PomodoroCore
import SwiftUI

/// A static, noninteractive preview using the same colors and glass as the timer.
public struct ThemeTimerPreview: View {
    public let phase: Phase
    public let orientation: PillOrientation
    @Environment(\.pomodoroTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    public init(phase: Phase = .focus, orientation: PillOrientation = .horizontal) {
        self.phase = phase; self.orientation = orientation
    }

    private var horizontalContents: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(.primary.opacity(0.14), lineWidth: 2.5)
                Circle().trim(from: 0, to: 0.65)
                    .stroke(LinearGradient(colors: [Theme.highlight(for: phase, in: theme), Theme.tint(for: phase, in: theme)],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: Theme.symbol(for: phase))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.legibleTint(for: phase, in: theme, scheme: colorScheme))
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(phase == .focus ? "18:42" : phase == .shortBreak ? "03:15" : "12:30")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(phase.title.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.legibleTint(for: phase, in: theme, scheme: colorScheme))
            }
            Spacer(minLength: 8)
            Image(systemName: "pause.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink(for: phase, in: theme))
                .frame(width: 30, height: 30)
                .background(Theme.tint(for: phase, in: theme), in: Circle())
            Image(systemName: "forward.end.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.primary.opacity(0.07), in: Circle())
        }
        .padding(.horizontal, 12)
        .frame(width: 236, height: 46)
    }

    private var verticalContents: some View {
        let layout = PillLayout(orientation: .vertical)
        let m = PillLayout.Metrics.self
        return ZStack(alignment: .topLeading) {
            ZStack {
                Circle().stroke(.primary.opacity(0.14), lineWidth: 2.5)
                Circle().trim(from: 0, to: 0.65)
                    .stroke(Theme.tint(for: phase, in: theme), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: Theme.symbol(for: phase))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.legibleTint(for: phase, in: theme, scheme: colorScheme))
            }
            .frame(width: m.ring, height: m.ring)
            .position(x: m.height / 2, y: m.leading + m.ring / 2)
            VStack(spacing: 3) {
                Text(phase == .focus ? "18:42" : phase == .shortBreak ? "03:15" : "12:30")
                    .font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit().tracking(-0.5)
                Text(phase == .focus ? "FOCUS" : phase == .shortBreak ? "BREAK" : "LONG")
                    .font(.system(size: 7, weight: .bold)).tracking(0.4)
                    .foregroundStyle(Theme.legibleTint(for: phase, in: theme, scheme: colorScheme))
            }
            .position(x: m.height / 2, y: m.leading + m.ring + m.ringGap + m.readout / 2)
            ForEach(0..<3) { index in
                let frame = layout.controlFrame(index: index).offsetBy(dx: -PillLayout.margin, dy: -PillLayout.margin)
                Image(systemName: ["pause.fill", "forward.end.fill", "arrow.counterclockwise"][index])
                    .font(.system(size: index == 0 ? 11 : 9, weight: .bold))
                    .foregroundStyle(index == 0 ? Theme.ink(for: phase, in: theme) : Color.secondary)
                    .frame(width: frame.width, height: frame.height)
                    .background(index == 0 ? Theme.tint(for: phase, in: theme) : Color.primary.opacity(0.07), in: Circle())
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }

    public var body: some View {
        Group {
            if orientation == .horizontal { horizontalContents } else { verticalContents }
        }
        .background(Theme.backdrop(for: phase, in: theme))
        .clipShape(Capsule())
        .glassPanel(in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phase.title) timer preview")
    }
}
