import AppIntents
import AppKit
import SwiftUI
import WidgetKit

@available(macOS 26.0, *)
struct TransOnRunningControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: TransOnControlConstants.controlKind,
            provider: Provider()
        ) { value in
            ControlWidgetButton(action: OpenTransOnAppIntent()) {
                Label(value.statusText, systemImage: value.icon.systemImageName)
            }
        }
        .displayName("Trans-On")
        .description("Shows whether Trans-On is currently running.")
    }
}

@available(macOS 26.0, *)
extension TransOnRunningControl {
    struct Provider: ControlValueProvider {
        var previewValue: TransOnControlState {
            TransOnControlState(isRunning: false, statusText: "Not Running", icon: .translate)
        }

        func currentValue() async throws -> TransOnControlState {
            TransOnControlState.current()
        }
    }
}

@available(macOS 26.0, *)
struct OpenTransOnAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Trans-On"
    static let description = IntentDescription("Launches or activates the Trans-On application.")

    func perform() async throws -> some IntentResult {
        let destination = TransOnSharedDefaults.shared.launchDestinationForCurrentConfiguration()
        let url = TransOnControlURL.makeURL(destination: destination)
        NSWorkspace.shared.open(url)
        return .result()
    }
}
