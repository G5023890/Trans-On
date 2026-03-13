import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage("sendAnalytics") private var sendAnalytics: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("PRIVACY")

                HStack {
                    Text("Send analytics")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(primaryText)

                    Spacer(minLength: 12)

                    Toggle("", isOn: $sendAnalytics)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cardBorder, lineWidth: 1)
                )

                Text("Anonymous usage data helps improve the app. No personal information is collected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(sectionText)
            .padding(.leading, 2)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03)
    }

    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06)
    }

    private var primaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.85)
    }

    private var sectionText: Color {
        colorScheme == .dark ? Color.white.opacity(0.34) : Color.black.opacity(0.30)
    }
}
