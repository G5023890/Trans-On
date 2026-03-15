import AppKit
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case auto = "Auto"
    case dark = "Dark"

    var id: Self { self }
}

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.auto.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var palette: SettingsGlassPalette {
        SettingsGlassPalette(colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionTitle(text: "General", palette: palette)

                GlassGroup(palette: palette) {
                    settingsRow(title: "Appearance") {
                        themePicker
                    }

                    GlassDivider(palette: palette)

                    settingsRow(title: "Display in") {
                        onOffPicker
                    }

                    GlassDivider(palette: palette)

                    settingsRow(title: "Control Center") {
                        controlCenterPicker
                    }

                    GlassDivider(palette: palette)

                    settingsRow(title: "Hotkey") {
                        HStack(spacing: 8) {
                            hotKeyCaps

                            Button(viewModel.isRecording ? "Recording..." : "Change") {
                                viewModel.beginRecording()
                            }
                            .buttonStyle(GlassButtonStyle(palette: palette))
                        }
                    }

                    GlassDivider(palette: palette)

                    settingsRow(title: "Text size") {
                        HStack(spacing: 8) {
                            stepperControl

                            Button("Reset") {
                                viewModel.updateFontSize(14)
                            }
                            .buttonStyle(GlassButtonStyle(palette: palette))
                        }
                    }

                    GlassDivider(palette: palette)

                    settingsRow(title: "Launch at login") {
                        Toggle("", isOn: Binding(
                            get: { viewModel.launchAtLogin },
                            set: { viewModel.updateLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(GlassToggleStyle(palette: palette))
                    }
                }

                messageBlock(text: viewModel.hotKeyError)
                messageBlock(text: viewModel.launchAtLoginError)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            applyAppearance(AppearanceMode(rawValue: appearanceModeRaw) ?? .auto)
        }
    }

    private func settingsRow<Content: View>(title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(palette.primaryText)

            Spacer(minLength: 12)

            trailing()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
    }

    private var themePicker: some View {
        HStack(spacing: 0) {
            ForEach(AppearanceMode.allCases) { mode in
                Button(mode.rawValue) {
                    appearanceBinding.wrappedValue = mode
                    applyAppearance(mode)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(appearanceBinding.wrappedValue == mode ? palette.primaryText : palette.secondaryText)
                .frame(height: 30)
                .frame(minWidth: 58)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(appearanceBinding.wrappedValue == mode ? palette.activeSidebarFill : .clear)
                )

                if mode != AppearanceMode.allCases.last {
                    Rectangle()
                        .fill(palette.separator)
                        .frame(width: 1, height: 18)
                }
            }
        }
        .padding(2)
        .background(palette.controlFill)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(palette.controlStroke, lineWidth: 1)
        )
    }

    private var onOffPicker: some View {
        HStack(spacing: 0) {
            ForEach(MenuBarDisplayMode.allCases) { mode in
                Button(mode.rawValue) {
                    viewModel.updateMenuBarDisplayMode(mode)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(viewModel.menuBarDisplayMode == mode ? palette.primaryText : palette.secondaryText)
                .frame(width: 46, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(viewModel.menuBarDisplayMode == mode ? palette.activeSidebarFill : .clear)
                )
            }
        }
        .padding(2)
        .background(palette.controlFill)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(palette.controlStroke, lineWidth: 1)
        )
    }

    private var controlCenterPicker: some View {
        Picker("", selection: Binding(
            get: { viewModel.controlCenterIcon },
            set: { viewModel.updateControlCenterIcon($0) }
        )) {
            ForEach(ControlCenterIconOption.allCases) { option in
                Label(option.title, systemImage: option.systemImageName).tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(width: 150)
    }

    private var hotKeyCaps: some View {
        HStack(spacing: 4) {
            ForEach(hotKeySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .frame(minWidth: 22)
                    .frame(height: 20)
                    .padding(.horizontal, 4)
                    .background(palette.keyCapFill)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(palette.keyCapStroke, lineWidth: 1)
                    )
            }
        }
    }

    private var stepperControl: some View {
        HStack(spacing: 0) {
            stepperButton("−") {
                viewModel.updateFontSize(viewModel.fontSizePt - 1)
            }

            Rectangle()
                .fill(palette.separator)
                .frame(width: 1, height: 18)

            Text("\(viewModel.fontSizePt) pt")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(palette.primaryText.opacity(0.82))
                .frame(minWidth: 48)
                .frame(height: 30)

            Rectangle()
                .fill(palette.separator)
                .frame(width: 1, height: 18)

            stepperButton("+") {
                viewModel.updateFontSize(viewModel.fontSizePt + 1)
            }
        }
        .background(palette.controlFill)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(palette.controlStroke, lineWidth: 1)
        )
    }

    private func stepperButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(palette.secondaryText)
                .frame(width: 28, height: 30)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func messageBlock(text: String?) -> some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.secondaryText)
                .padding(.leading, 2)
        }
    }

    private var hotKeySymbols: [String] {
        viewModel.hotKey.displayString.map { String($0) }
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceModeRaw) ?? .auto },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        NSApp.appearance = switch mode {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .auto: nil
        }
    }
}
