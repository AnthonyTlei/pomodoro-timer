import PomodoroCore
import SwiftUI

/// A static, noninteractive preview using the same colors and glass as the timer.
public struct ThemeTimerPreview: View {
    public let phase: Phase
    @Environment(\.pomodoroTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    public init(phase: Phase = .focus) { self.phase = phase }

    public var body: some View {
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
        .background(Theme.backdrop(for: phase, in: theme))
        .clipShape(Capsule())
        .glassPanel(in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phase.title) timer preview")
    }
}
