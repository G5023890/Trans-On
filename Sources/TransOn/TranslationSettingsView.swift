import SwiftUI

struct TranslationSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @AppStorage("translationEngine") private var translationEngineRaw: String = TranslationEngine.googleWeb.rawValue
    @Environment(\.colorScheme) private var colorScheme

    @State private var googleCloudApiKeyText: String = ""
    @State private var testState: TestState = .idle
    @State private var localModelState: TestState = .idle

    private enum TestState {
        case idle
        case testing
        case valid
        case invalid
    }

    private var palette: SettingsGlassPalette {
        SettingsGlassPalette(colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionTitle(text: "Engine", palette: palette)

                GlassGroup(palette: palette) {
                    engineRow(.googleWeb, subtitle: "(gtx)")
                    GlassDivider(palette: palette)
                    engineRow(.googleAPI, subtitle: nil)
                    GlassDivider(palette: palette)
                    engineRow(.nativeLocal, subtitle: "(offline)")
                }

                if isGoogleCloudEngine {
                    apiKeyBlock
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if isLocalEngine {
                    localHelperBlock
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if isGoogleCloudEngine, viewModel.googleCloudDiagnosticTitle.contains("failed") {
                    Text("Последняя ошибка: \(viewModel.googleCloudDiagnosticDetail)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(.leading, 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !viewModel.cloudStatusMessage.isEmpty {
                    Text(viewModel.cloudStatusMessage)
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.secondaryText)
                        .padding(.leading, 2)
                }

                if isLocalEngine, !viewModel.localTranslationStatusMessage.isEmpty {
                    Text(viewModel.localTranslationStatusMessage)
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.secondaryText)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.18), value: isGoogleCloudEngine)
        .animation(.easeInOut(duration: 0.18), value: isLocalEngine)
        .onAppear {
            if TranslationEngine(rawValue: translationEngineRaw) == nil {
                translationEngineRaw = TranslationEngine.googleWeb.rawValue
                AppSettings.shared.setTranslationEngine(.googleWeb)
            }

            if googleCloudApiKeyText.isEmpty {
                googleCloudApiKeyText = AppSettings.shared.googleCloudApiKey
            }

            if isLocalEngine {
                Task { @MainActor in
                    _ = await viewModel.refreshLocalTranslationStatus()
                }
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
            localModelState = .idle

            if engine == .nativeLocal {
                Task { @MainActor in
                    _ = await viewModel.refreshLocalTranslationStatus()
                }
            }
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

    private func engineRow(_ engine: TranslationEngine, subtitle: String?) -> some View {
        Button {
            translationEngineRaw = engine.rawValue
        } label: {
            HStack(spacing: 12) {
                radioIndicator(isSelected: translationEngineRaw == engine.rawValue)

                HStack(spacing: 4) {
                    Text(engine.title)
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(palette.primaryText)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(palette.secondaryText.opacity(0.8))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func radioIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.accentColor : palette.secondaryText.opacity(0.45), lineWidth: 1.8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.white.opacity(palette.isDark ? 0.05 : 0.22))
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
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 5)

            VStack(alignment: .leading, spacing: 8) {
                Text("Google Cloud API key")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.accentColor.opacity(0.9))

                HStack(spacing: 8) {
                    SecureField("••••••••••••••••••", text: $googleCloudApiKeyText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.primaryText.opacity(0.86))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .clipped()
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(palette.inputFill)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(palette.inputStroke, lineWidth: 1)
                        )

                    Button(action: testAPIKey) {
                        testButtonContent
                    }
                    .buttonStyle(GlassButtonStyle(palette: palette, prominent: true, tint: testButtonTint))
                    .disabled(googleCloudApiKeyText.isEmpty || testState == .testing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(palette.apiCardFill)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.apiCardStroke, lineWidth: 1)
        )
    }

    private var localHelperBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.95), Color.yellow.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 5)

            VStack(alignment: .leading, spacing: 8) {
                Text("Local OPUS-MT helper")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.orange.opacity(0.92))

                Text("Downloads OPUS-MT models into Application Support and runs them locally. English is translated directly; Hebrew pivots through English.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.primaryText.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 8) {
                    Button(action: prepareLocalModels) {
                        localButtonContent
                    }
                    .buttonStyle(GlassButtonStyle(palette: palette, prominent: true, tint: localButtonTint))
                    .disabled(localModelState == .testing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cache: \(viewModel.localTranslationCacheDisplay)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)

                        Text("No account, no card, no cloud dependency.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(palette.secondaryText.opacity(0.84))
                    }
                }

                if !viewModel.localTranslationDetail.isEmpty {
                    Text(viewModel.localTranslationDetail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.secondaryText.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(palette.apiCardFill)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.apiCardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var testButtonContent: some View {
        switch testState {
        case .idle:
            Text("Test")
        case .testing:
            Text("Testing...")
        case .valid:
            Label("Valid", systemImage: "checkmark")
        case .invalid:
            Label("Failed", systemImage: "xmark")
        }
    }

    @ViewBuilder
    private var localButtonContent: some View {
        switch localModelState {
        case .idle:
            Text("Prepare / Update")
        case .testing:
            Text("Working...")
        case .valid:
            Label("Ready", systemImage: "checkmark")
        case .invalid:
            Label("Failed", systemImage: "xmark")
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

    private var localButtonTint: Color {
        switch localModelState {
        case .valid:
            return .green
        case .invalid:
            return .red
        default:
            return .orange
        }
    }

    private var isGoogleCloudEngine: Bool {
        translationEngineRaw == TranslationEngine.googleAPI.rawValue
    }

    private var isLocalEngine: Bool {
        translationEngineRaw == TranslationEngine.nativeLocal.rawValue
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

    private func prepareLocalModels() {
        localModelState = .testing
        Task { @MainActor in
            let status = await viewModel.prepareLocalTranslationModels()
            localModelState = status.ready ? .valid : .invalid
        }
    }

    private func sanitizeAPIKey(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines).joined()
    }
}
