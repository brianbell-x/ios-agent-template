import SwiftUI

@main
struct ChatAgentTemplateApp: App {
    private let environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootScene(environment: environment)
        }
    }
}

private struct RootScene: View {
    @State private var store: ChatSessionStore

    init(environment: AppEnvironment) {
        _store = State(
            initialValue: ChatSessionStore(
                client: environment.client,
                transcriptStore: environment.transcriptStore,
                backendBaseURL: environment.backendBaseURL,
                defaultAgentID: environment.defaultAgentID,
                localTranscriptLimit: environment.localTranscriptLimit
            )
        )
    }

    var body: some View {
        NavigationStack {
            ChatView(store: store)
        }
        .task {
            await store.restoreIfNeeded()
        }
    }
}
