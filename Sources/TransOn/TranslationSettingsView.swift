import SwiftUI

struct TranslationSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @AppStorage("translationEngine") private var translationEngineRaw: String = TranslationEngine.googleWeb.rawValue
    @Environment(\.colorScheme) private var colorScheme

    @State private var googleCloudApiKeyText: String = ""
    @State private var testState: TestState = .idle

    private enum TestState {
        case idle
        case testing
        case valid
        case invalid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("ENGINE")

                VStack(spacing: 0) {
                    engineRow(.googleWeb)
                    divider
                    engineRow(.googleAPI)
                }
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cardBorder, lineWidth: 1)
                )

                if isGoogleCloudEngine {
                    apiKeyBlock
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !viewModel.cloudStatusMessage.isEmpty {
                    Text(viewModel.cloudStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)
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
        .animation(.easeInOut(duration: 0.18), value: isGoogleCloudEngine)
        .onAppear {
            if TranslationEngine(rawValue: translationEngineRaw) == nil {
                translationEngineRaw = TranslationEngine.googleWeb.rawValue
                AppSettings.shared.setTranslationEngine(.googleWeb)
            }

            if googleCloudApiKeyText.isEmpty {
                googleCloudApiKeyText = AppSettings.shared.googleCloudApiKey
            }
        }
        .onChange(of: translationEngineRaw) { _, newValue in
            guard let engine = TranslationEngine(rawValue: newValue) else {
                translationEngineRaw = TranslationEngine.googleWeb.rawValue
                AppSettings.shared.setTranslationEngine(.googleWeb)
                return
            }
            AppSettings.shared.setTranslationEngine(engine)
            testState = .idle
        }
        .onChange(of: googleCloudApiKeyText) { _, newValue in
            let sanitized = sanitizeAPIKey(newValue)
            if sanitized != newValue {
                googleCloudApiKeyText = sanitized
                return
            }
            if testState != .idle {
                testState = .idle
            }
        }
        .onDisappear {
            if isGoogleCloudEngine {
                viewModel.verifyGoogleAPIKey(googleCloudApiKeyText)
            }
        }
    }

    private func engineRow(_ engine: TranslationEngine) -> some View {
        Button {
            translationEngineRaw = engine.rawValue
        } label: {
            HStack(spacing: 11) {
                radioIndicator(isSelected: translationEngineRaw == engine.rawValue)

                if engine == .googleWeb {
                    (Text("Google Web")
                        .foregroundStyle(primaryText)
                     + Text("  (gtx)")
                        .foregroundStyle(sectionText))
                        .font(.system(size: 13.5, weight: .regular))
                } else {
                    Text(engine.title)
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(primaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func radioIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.accentColor : radioBorder, lineWidth: 2)
                .frame(width: 18, height: 18)
            if isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var apiKeyBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: 3)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 8) {
                Text("GOOGLE CLOUD API KEY")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.3)
                    .foregroundStyle(Color.accentColor.opacity(0.9))

                HStack(spacing: 8) {
                    SecureField("••••••••••••••••••", text: $googleCloudApiKeyText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .clipped()
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(apiInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(apiInputBorder, lineWidth: 1)
                        )

                    Button(action: testAPIKey) {
                        testButtonContent
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(testButtonTint)
                    .disabled(googleCloudApiKeyText.isEmpty || testState == .testing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(apiBlockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(apiBlockBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var testButtonContent: some View {
        switch testState {
        case .idle:
            Text("Test")
                .font(.system(size: 13, weight: .medium))
        case .testing:
            ProgressView()
                .controlSize(.small)
        case .valid:
            Label("Valid", systemImage: "checkmark")
                .font(.system(size: 11, weight: .semibold))
        case .invalid:
            Label("Failed", systemImage: "xmark")
                .font(.system(size: 11, weight: .semibold))
        }
    }

    private var testButtonTint: Color {
        switch testState {
        case .valid:
            return .green
        case .invalid:
            return .red
        default:
            return .accentColor
        }
    }

    private var isGoogleCloudEngine: Bool {
        translationEngineRaw == TranslationEngine.googleAPI.rawValue
    }

    private func testAPIKey() {
        let candidate = sanitizeAPIKey(googleCloudApiKeyText)
        googleCloudApiKeyText = candidate

        guard !candidate.isEmpty else {
            testState = .invalid
            viewModel.cloudStatusMessage = "Ключ пустой."
            return
        }

        testState = .testing

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_050_000_000)

            guard candidate == googleCloudApiKeyText else { return }

            let isValidFormat = candidate.hasPrefix("AIza") && candidate.count >= 20
            if isValidFormat {
                viewModel.verifyGoogleAPIKey(candidate)
                testState = .valid
            } else {
                viewModel.cloudStatusMessage = "Проверьте формат ключа Google Cloud API."
                testState = .invalid
            }

            try? await Task.sleep(nanoseconds: 2_100_000_000)
            if candidate == googleCloudApiKeyText {
                testState = .idle
            }
        }
    }

    private func sanitizeAPIKey(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(sectionText)
            .padding(.leading, 2)
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

    private var apiBlockBackground: Color {
        colorScheme == .dark ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.08)
    }

    private var apiBlockBorder: Color {
        colorScheme == .dark ? Color.accentColor.opacity(0.34) : Color.accentColor.opacity(0.24)
    }

    private var apiInputBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    private var apiInputBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
    }

    private var radioBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.26) : Color.black.opacity(0.20)
    }

    private var primaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.85)
    }

    private var sectionText: Color {
        colorScheme == .dark ? Color.white.opacity(0.34) : Color.black.opacity(0.30)
    }
}
