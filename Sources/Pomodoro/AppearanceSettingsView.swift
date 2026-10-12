import AppKit
import PomodoroCore
import PomodoroUI
import SwiftUI

/// Presets first, deeper controls on demand. Changes preview and persist immediately.
struct AppearanceSettingsView: View {
    @Bindable var settings: PomodoroSettings
    @State private var previewPhase: Phase = .focus
    @State private var showingColors = false
    @Environment(\.colorScheme) private var colorScheme

    private var theme: ThemeConfiguration { settings.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            preview
            presets
            Divider().opacity(0.4)
            appearance
            DisclosureGroup("Customize colors", isExpanded: $showingColors) {
                colorControls.padding(.top, 12)
            }
            .font(.system(size: 12, weight: .medium))

            HStack(alignment: .top) {
                Text("Changes apply instantly. Your custom colors stay saved when you try another preset.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button("Reset") { settings.theme = ThemeConfiguration() }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .help("Restore the original colors and System appearance")
            }
        }
        .font(.system(size: 12))
    }

    private var preview: some View {
        VStack(spacing: 12) {
            ThemeTimerPreview(phase: previewPhase)
                .pomodoroAppearance(theme)
                .accessibilityLabel("\(previewPhase.title) theme preview")
            Picker("Preview phase", selection: $previewPhase) {
                ForEach(Phase.allCases, id: \.self) { phase in
                    Text(phase.title).tag(phase)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("LIVE PREVIEW")
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Palette").font(.system(size: 12, weight: .semibold))
                Spacer()
                if let match = ThemePreset.matching(settings.character) {
                    Button("Match character") { select(match) }
                        .font(.system(size: 10))
                        .buttonStyle(.borderless)
                        .help("Use the \(match.name) palette without changing your character")
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ThemePreset.allCases) { preset in presetCard(preset) }
            }
        }
    }

    private func select(_ preset: ThemePreset) {
        var configuration = theme
        if preset == .custom && configuration.customPalette == nil {
            configuration.customPalette = configuration.palette
        }
        configuration.preset = preset
        settings.theme = configuration
    }

    private func presetCard(_ preset: ThemePreset) -> some View {
        let selected = theme.preset == preset
        let palette = preset == .custom ? theme.customPalette ?? theme.palette : preset.palette
        return Button { select(preset) } label: {
            HStack(spacing: 8) {
                if let character = preset.character {
                    IdleCharacterDrawing(character: character, motion: .sample(time: 0, mode: .off))
                        .scaleEffect(0.68)
                        .frame(width: 26, height: 34)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: preset == .custom ? "slider.horizontal.3" : "circle.lefthalf.filled")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 34)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.name)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        ForEach(Phase.allCases, id: \.self) { phase in
                            Capsule().fill(palette[phase].tint.color).frame(width: 19, height: 4)
                        }
                    }
                    .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.legibleTint(for: .focus, in: theme, scheme: colorScheme))
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 49)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(selected ? 0.07 : 0.025), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Theme.legibleTint(for: .focus, in: theme, scheme: colorScheme).opacity(0.6) : .primary.opacity(0.08),
                                  lineWidth: selected ? 1 : 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name) palette")
        .accessibilityValue(selected ? "Selected" : "")
        .help(preset.detail)
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Appearance", selection: Binding(
                get: { theme.appearance },
                set: { value in update { $0.appearance = value } }
            )) {
                ForEach(ThemeAppearance.allCases) { appearance in
                    Text(appearance.name).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            HStack {
                Text("Surface tint").font(.system(size: 11))
                Slider(value: Binding(get: { theme.surfaceStrength }, set: { value in update { $0.surfaceStrength = value } }), in: 0...1)
                    .accessibilityLabel("Surface tint strength")
                Text("\(Int((theme.surfaceStrength * 100).rounded()))%")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    private var colorControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Phase.allCases, id: \.self) { phase in
                colorRow(phase.title, color: Binding(
                    get: { theme.palette[phase].tint },
                    set: { color in customize { $0[phase] = PhaseColors(tint: color) } }
                ))
            }
            Divider().opacity(0.4)
            Toggle("Surfaces follow the current phase", isOn: Binding(
                get: { theme.palette.surface == nil },
                set: { follows in customize { $0.surface = follows ? nil : $0.focus.tint } }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 11))
            if let surface = theme.palette.surface {
                colorRow("Surface color", color: Binding(
                    get: { theme.palette.surface ?? surface },
                    set: { color in customize { $0.surface = color } }
                ))
            }
            Text("Progress rings, buttons, cycle indicators and charts share these colors. Text stays readable automatically. Character artwork keeps its original colors.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func colorRow(_ title: String, color: Binding<ThemeColor>) -> some View {
        HStack {
            Text(title).font(.system(size: 11))
            Spacer()
            Text(color.wrappedValue.hexString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            ColorPicker(title, selection: Binding(
                get: { color.wrappedValue.color },
                set: { selected in
                    guard let rgb = NSColor(selected).usingColorSpace(.sRGB) else { return }
                    let red = UInt32((min(max(rgb.redComponent, 0), 1) * 255).rounded())
                    let green = UInt32((min(max(rgb.greenComponent, 0), 1) * 255).rounded())
                    let blue = UInt32((min(max(rgb.blueComponent, 0), 1) * 255).rounded())
                    color.wrappedValue = ThemeColor(red << 16 | green << 8 | blue)
                }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }

    private func update(_ change: (inout ThemeConfiguration) -> Void) {
        var configuration = theme
        change(&configuration)
        settings.theme = configuration
    }
    private func customize(_ change: (inout ThemePalette) -> Void) {
        update { $0.customize(change) }
    }
}
