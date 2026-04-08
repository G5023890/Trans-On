import SwiftUI

struct DiagnosticsSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: SettingsGlassPalette {
        SettingsGlassPalette(colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionTitle(text: "Diagnostics", palette: palette)

                GlassGroup(palette: palette) {
                    diagnosticRow(
                        title: "Google Cloud API",
                        value: viewModel.googleCloudDiagnosticTitle,
                        valueColor: viewModel.googleCloudDiagnosticTitle.hasSuffix("failed") ? .red : .green
                    )

                    GlassDivider(palette: palette)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest reason")
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundStyle(palette.primaryText)

                        Text(viewModel.googleCloudDiagnosticDetail)
                            .font(.system(size: 12.5))
                            .foregroundStyle(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)

                    GlassDivider(palette: palette)

                    diagnosticRow(
                        title: "Updated",
                        value: viewModel.googleCloudDiagnosticUpdatedAt,
                        valueColor: palette.primaryText
                    )

                    GlassDivider(palette: palette)

                    HStack {
                        Spacer(minLength: 0)

                        Button("Clear") {
                            viewModel.clearGoogleCloudDiagnostics()
                        }
                        .buttonStyle(GlassButtonStyle(palette: palette))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                Text("If Google Cloud fails, the app records the latest error here and can still fall back to Google Web.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondaryText)
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func diagnosticRow(title: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(palette.primaryText)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}
