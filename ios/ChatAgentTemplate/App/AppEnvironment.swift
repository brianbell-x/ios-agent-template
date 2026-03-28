import Foundation

struct AppEnvironment {
    let client: any ChatAPIClient
    let transcriptStore: TranscriptStore
    let backendBaseURL: URL
    let defaultAgentID: String

    static func live(bundle: Bundle = .main) -> AppEnvironment {
        let baseURLString =
            (bundle.object(forInfoDictionaryKey: "ChatBackendBaseURL") as? String)
            ?? "http://127.0.0.1:8000"
        let defaultAgentID =
            (bundle.object(forInfoDictionaryKey: "ChatDefaultAgentID") as? String)
            ?? "default"
        let baseURL = URL(string: baseURLString) ?? URL(string: "http://127.0.0.1:8000")!

        return AppEnvironment(
            client: LiveChatAPIClient(baseURL: baseURL),
            transcriptStore: .live(),
            backendBaseURL: baseURL,
            defaultAgentID: defaultAgentID
        )
    }
}
