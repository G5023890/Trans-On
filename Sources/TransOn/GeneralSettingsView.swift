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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("GENERAL")

                VStack(spacing: 0) {
                    appearanceRow

                    divider
                    settingsRow(title: "Display in") {
                        Picker("", selection: Binding(
                            get: { viewModel.menuBarDisplayMode },
                            set: { viewModel.updateMenuBarDisplayMode($0) }
                        )) {
                            ForEach(MenuBarDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 120)
                    }

                    divider
                    settingsRow(title: "Control Center icon") {
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
                        .frame(width: 160)
                    }

                    divider
                    settingsRow(title: "Hotkey") {
                        HStack(spacing: 8) {
                            hotKeyCaps
                            Button("Change") {
                                viewModel.beginRecording()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    divider
                    settingsRow(title: "Text size") {
                        HStack(spacing: 8) {
                            stepperControl
                            Button("Reset") {
                                viewModel.updateFontSize(14)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    divider
                    settingsRow(title: "Launch at login") {
                        Toggle("", isOn: Binding(
                            get: { viewModel.launchAtLogin },
                            set: { viewModel.updateLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cardBorder, lineWidth: 1)
                )

                if let hotKeyError = viewModel.hotKeyError {
                    Text(hotKeyError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let launchAtLoginError = viewModel.launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            applyAppearance(AppearanceMode(rawValue: appearanceModeRaw) ?? .auto)
        }
    }

    private var appearanceRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(primaryText)

            Picker("", selection: appearanceBinding) {
                Label("Light", systemImage: "sun.max.fill").tag(AppearanceMode.light)
                Label("Auto", systemImage: "display").tag(AppearanceMode.auto)
                Label("Dark", systemImage: "moon.fill").tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .onChange(of: appearanceBinding.wrappedValue) { _, mode in
                applyAppearance(mode)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func settingsRow<Content: View>(title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(primaryText)

            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var hotKeyCaps: some View {
        HStack(spacing: 4) {
            ForEach(hotKeySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryText)
                    .frame(minWidth: 22)
                    .frame(height: 20)
                    .padding(.horizontal, 4)
                    .background(keyCapBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(keyCapBorder, lineWidth: 1)
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
                .fill(stepperBorder)
                .frame(width: 1, height: 16)

            Text("\(viewModel.fontSizePt) pt")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(primaryText)
                .frame(minWidth: 50)
                .frame(height: 26)

            Rectangle()
                .fill(stepperBorder)
                .frame(width: 1, height: 16)

            stepperButton("+") {
                viewModel.updateFontSize(viewModel.fontSizePt + 1)
            }
        }
        .background(stepperBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(stepperBorder, lineWidth: 1)
        )
    }

    private func stepperButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(secondaryText)
                .frame(width: 24, height: 26)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(sectionText)
            .padding(.leading, 2)
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

    private var divider: some View {
        Rectangle()
            .fill(cardBorder)
            .frame(height: 1)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03)
    }

    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06)
    }

    private var keyCapBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var keyCapBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.13)
    }

    private var stepperBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.05)
    }

    private var stepperBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }

    private var primaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.85)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.55)
    }

    private var sectionText: Color {
        colorScheme == .dark ? Color.white.opacity(0.34) : Color.black.opacity(0.30)
    }
}
