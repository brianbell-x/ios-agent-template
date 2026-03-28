import SwiftUI

@main
struct ChatAgentApp: App {
    private let launchState: LaunchState

    @MainActor
    init() {
        do {
            let environment = try AppEnvironment.live()
            launchState = .ready(
                ChatSessionStore(
                    client: environment.client,
                    transcriptStore: environment.transcriptStore,
                    backendBaseURL: environment.backendBaseURL,
                    localTranscriptLimit: environment.localTranscriptLimit
                )
            )
        } catch let error as AppEnvironment.ConfigurationError {
            AppEnvironment.reportStartupConfigurationError(error)
            launchState = .failed(error.localizedDescription)
        } catch {
            let fallbackError = AppEnvironment.ConfigurationError.unexpected(error.localizedDescription)
            AppEnvironment.reportStartupConfigurationError(fallbackError)
            launchState = .failed(fallbackError.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch launchState {
            case .ready(let store):
                RootScene(store: store)
            case .failed(let message):
                StartupConfigurationErrorView(message: message)
            }
        }
    }
}

private enum LaunchState {
    case ready(ChatSessionStore)
    case failed(String)
}

private struct RootScene: View {
    let store: ChatSessionStore

    var body: some View {
        NavigationStack {
            ChatView(screen: store.screen)
        }
        .task {
            await store.restoreIfNeeded()
        }
    }
}

private struct StartupConfigurationErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Label("Configuration Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.orange)

                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Update the required `Chat*` values in the app Info.plist, then relaunch.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 420, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
    }
}
