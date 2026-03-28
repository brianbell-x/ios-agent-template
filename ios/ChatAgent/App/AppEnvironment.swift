import CoreFoundation
import Foundation
import OSLog

struct AppEnvironment {
    private enum NonProductionDefaults {
        static let backendBaseURL = URL(string: "http://127.0.0.1:8000")!
        static let localTranscriptLimit = 40
    }

    enum ConfigurationError: LocalizedError {
        case missingBackendBaseURL
        case malformedBackendBaseURL(String)
        case missingLocalTranscriptLimit
        case malformedLocalTranscriptLimit(String)
        case unexpected(String)

        var errorDescription: String? {
            switch self {
            case .missingBackendBaseURL:
                return "Startup configuration error: `ChatBackendBaseURL` is missing from Info.plist."
            case .malformedBackendBaseURL(let value):
                return "Startup configuration error: `ChatBackendBaseURL` must be a valid http or https URL. Received `\(value)`."
            case .missingLocalTranscriptLimit:
                return "Startup configuration error: `ChatLocalTranscriptLimit` is missing from Info.plist."
            case .malformedLocalTranscriptLimit(let value):
                return "Startup configuration error: `ChatLocalTranscriptLimit` must be a positive integer. Received `\(value)`."
            case .unexpected(let message):
                return "Startup configuration error: \(message)"
            }
        }
    }

    let client: any ChatAPIClient
    let transcriptStore: TranscriptStore
    let backendBaseURL: URL
    let localTranscriptLimit: Int

    static func live(bundle: Bundle = .main) throws -> AppEnvironment {
        let baseURL = try configuredBackendBaseURL(bundle: bundle)
        let localTranscriptLimit = try configuredLocalTranscriptLimit(bundle: bundle)

        return AppEnvironment(
            client: LiveChatAPIClient(baseURL: baseURL),
            transcriptStore: .live(),
            backendBaseURL: baseURL,
            localTranscriptLimit: localTranscriptLimit
        )
    }

    static func nonProduction(
        client: any ChatAPIClient,
        transcriptStore: TranscriptStore = .preview(),
        backendBaseURL: URL = NonProductionDefaults.backendBaseURL,
        localTranscriptLimit: Int = NonProductionDefaults.localTranscriptLimit
    ) -> AppEnvironment {
        AppEnvironment(
            client: client,
            transcriptStore: transcriptStore,
            backendBaseURL: backendBaseURL,
            localTranscriptLimit: localTranscriptLimit
        )
    }

    static func reportStartupConfigurationError(_ error: ConfigurationError) {
        let message = error.localizedDescription
        logger.fault("\(message, privacy: .public)")

        #if DEBUG
        assertionFailure(message)
        #endif
    }

    private static func configuredBackendBaseURL(bundle: Bundle) throws -> URL {
        guard let rawValue = bundle.object(forInfoDictionaryKey: "ChatBackendBaseURL") as? String else {
            throw ConfigurationError.missingBackendBaseURL
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedValue.isEmpty,
            let baseURL = URL(string: trimmedValue),
            let scheme = baseURL.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            baseURL.host != nil
        else {
            throw ConfigurationError.malformedBackendBaseURL(rawValue)
        }

        return baseURL
    }

    private static func configuredLocalTranscriptLimit(bundle: Bundle) throws -> Int {
        guard let rawValue = bundle.object(forInfoDictionaryKey: "ChatLocalTranscriptLimit") else {
            throw ConfigurationError.missingLocalTranscriptLimit
        }
        guard
            let value = rawValue as? NSNumber,
            CFGetTypeID(value) != CFBooleanGetTypeID(),
            value.intValue > 0
        else {
            throw ConfigurationError.malformedLocalTranscriptLimit(String(describing: rawValue))
        }

        return value.intValue
    }
}

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ChatAgent",
    category: "AppEnvironment"
)
