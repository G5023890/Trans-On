import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: SettingsGlassPalette {
        SettingsGlassPalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            HStack(spacing: 0) {
                sidebar

                Rectangle()
                    .fill(palette.separator)
                    .frame(width: 1)

                detail
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.panelFill)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(palette.panelStroke.opacity(0.8), lineWidth: 1)
        )
        .frame(minWidth: 760, minHeight: 500)
        .ignoresSafeArea(.container, edges: .top)
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

    private var titleBar: some View {
        ZStack {
            HStack(spacing: 8) {
                trafficDot(fill: Color(red: 1.00, green: 0.37, blue: 0.34))
                trafficDot(fill: Color(red: 1.00, green: 0.74, blue: 0.18))
                trafficDot(fill: Color(red: 0.16, green: 0.78, blue: 0.25))
                Spacer(minLength: 0)
            }

            Text("Settings")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.primaryText.opacity(0.78))
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        viewModel.selectedSection = section
                    }
                } label: {
                    HStack(spacing: 10) {
                        sidebarIcon(for: section)

                        Text(section.title)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundStyle(sidebarTextColor(for: section))

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(sidebarItemBackground(for: section))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(width: 170)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(palette.sidebarFill)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch viewModel.selectedSection {
            case .general:
                GeneralSettingsView(viewModel: viewModel)
            case .translation:
                TranslationSettingsView(viewModel: viewModel)
            case .diagnostics:
                DiagnosticsSettingsView(viewModel: viewModel)
            case .privacy:
                PrivacySettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sidebarIcon(for section: SettingsSection) -> some View {
        let gradient: LinearGradient = switch section {
        case .general:
            LinearGradient(colors: [Color(red: 0.64, green: 0.64, blue: 0.68), Color(red: 0.43, green: 0.43, blue: 0.46)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .translation:
            LinearGradient(colors: [Color(red: 0.24, green: 0.61, blue: 1.00), Color(red: 0.04, green: 0.44, blue: 0.87)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .diagnostics:
            LinearGradient(colors: [Color(red: 1.00, green: 0.67, blue: 0.18), Color(red: 0.86, green: 0.36, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .privacy:
            LinearGradient(colors: [Color(red: 0.23, green: 0.82, blue: 0.42), Color(red: 0.12, green: 0.66, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(gradient)
                .frame(width: 22, height: 22)

            Image(systemName: section.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
    }

    private func sidebarItemBackground(for section: SettingsSection) -> Color {
        viewModel.selectedSection == section ? palette.activeSidebarFill : .clear
    }

    private func sidebarTextColor(for section: SettingsSection) -> Color {
        viewModel.selectedSection == section ? palette.activeSidebarText : palette.inactiveSidebarText
    }

    private func trafficDot(fill: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 12, height: 12)
            .shadow(color: Color.black.opacity(0.12), radius: 1)
    }
}
