import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            windowBackground
                .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar

                Rectangle()
                    .fill(borderColor)
                    .frame(width: 1)

                detail
            }
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(panelBorder, lineWidth: 1)
            )
            .padding(10)
        }
        .frame(minWidth: 720, minHeight: 420)
        .sheet(isPresented: Binding(
            get: { viewModel.isRecording },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelRecording()
                }
            }
        )) {
            HotKeyRecorderSheet(viewModel: viewModel)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    viewModel.selectedSection = section
                } label: {
                    HStack(spacing: 9) {
                        sidebarIcon(for: section)

                        Text(section.title)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundStyle(sidebarTextColor(for: section))

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(sidebarItemBackground(for: section))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(width: 180)
        .background(sidebarBackground)
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.selectedSection {
        case .general:
            GeneralSettingsView(viewModel: viewModel)
                .transition(.opacity)
        case .translation:
            TranslationSettingsView(viewModel: viewModel)
                .transition(.opacity)
        case .privacy:
            PrivacySettingsView()
                .transition(.opacity)
        }
    }

    private func sidebarIcon(for section: SettingsSection) -> some View {
        let fill: Color
        switch section {
        case .general:
            fill = colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.45)
        case .translation:
            fill = Color.accentColor
        case .privacy:
            fill = Color.green
        }

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fill)
                .frame(width: 24, height: 24)

            Image(systemName: section.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func sidebarItemBackground(for section: SettingsSection) -> Color {
        if viewModel.selectedSection == section {
            return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07)
        }
        return .clear
    }

    private func sidebarTextColor(for section: SettingsSection) -> Color {
        if viewModel.selectedSection == section {
            return colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.86)
        }
        return colorScheme == .dark ? Color.white.opacity(0.48) : Color.black.opacity(0.45)
    }

    private var windowBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.11, blue: 0.13)
            : Color(red: 0.91, green: 0.91, blue: 0.93)
    }

    private var panelBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.16, blue: 0.18)
            : Color(red: 0.95, green: 0.95, blue: 0.96)
    }

    private var sidebarBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.13, green: 0.14, blue: 0.16)
            : Color(red: 0.90, green: 0.90, blue: 0.92)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }

    private var panelBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }
}
