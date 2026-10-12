import PomodoroCore
import PomodoroUI
import SwiftUI

/// Preview and placement share the production dock renderer. Choosing Lively
/// demonstrates its first transition immediately, then settles into quiet rests.
struct CompanionSettingsView: View {
    @Bindable var settings: PomodoroSettings
    private let previewBounds = CGRect(x: 0, y: 0, width: 400, height: 170)
    private let pill = CGRect(x: 82, y: 52, width: 236, height: 46)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                ThemeTimerPreview(phase: .focus)
                    .position(x: pill.midX, y: pill.midY)
                HangingCompanion(character: settings.character, mode: settings.characterIdleMode,
                    edge: settings.characterCompanionEdge, position: settings.characterCompanionPosition,
                    pill: pill, screen: previewBounds)
            }
            .frame(width: previewBounds.width, height: previewBounds.height)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Hanging companion live preview")

            Picker(settings.characterIdleMode == .stroll ? "Start at" : "Hang from",
                   selection: $settings.characterCompanionEdge) {
                Text("Top").tag(StageEdge.top)
                Text("Bottom").tag(StageEdge.bottom)
                Text("Left").tag(StageEdge.leading)
                Text("Right").tag(StageEdge.trailing)
            }
            .pickerStyle(.segmented)

            if settings.characterCompanionEdge == .top || settings.characterCompanionEdge == .bottom {
                HStack(spacing: 10) {
                    Text("Position").font(.system(size: 11))
                    Slider(value: $settings.characterCompanionPosition, in: 0...1)
                        .accessibilityLabel("Position along the pill")
                    Button("Center") { settings.characterCompanionPosition = 0.5 }
                        .font(.system(size: 10)).buttonStyle(.borderless)
                }
            }

            Text(settings.characterIdleMode == .stroll
                ? "A little movement, then a quiet rest. She changes sides occasionally and stays clear of screen edges."
                : "Pick her spot. She stays there with gentle breathing and blinking, moving only when a screen edge gets in the way.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(settings.characterIdleMode == .off || !settings.showFloatingBar)
    }
}
