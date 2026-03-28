import Foundation

protocol ChatAPIClient {
    func streamReply(for request: BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>
    func conversationStatus(for conversationID: String) async throws -> ConversationStatusPayload
}

enum ChatAPIError: LocalizedError {
    case invalidResponse
    case unacceptableStatusCode(Int)
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The backend returned an invalid response."
        case .unacceptableStatusCode(let code):
            return "The backend returned HTTP \(code)."
        case .server(let message):
            return message
        }
    }
}

struct LiveChatAPIClient: ChatAPIClient {
    let baseURL: URL
    var session: URLSession = .shared

    func conversationStatus(for conversationID: String) async throws -> ConversationStatusPayload {
        let statusURL = baseURL.appending(path: "/api/conversations/\(conversationID)")
        let (data, response) = try await session.data(from: statusURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ChatAPIError.unacceptableStatusCode(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(ConversationStatusPayload.self, from: data)
    }

    func streamReply(for request: BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var urlRequest = URLRequest(url: baseURL.appending(path: "/api/chat/stream"))
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ChatAPIError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw ChatAPIError.unacceptableStatusCode(httpResponse.statusCode)
                    }

                    var parser = ChatStreamParser()
                    for try await line in bytes.lines {
                        if let event = try parser.consume(line: line) {
                            if case .failure(let payload) = event {
                                throw ChatAPIError.server(message: payload.message)
                            }
                            continuation.yield(event)
                        }
                    }

                    if let trailingEvent = try parser.finish() {
                        if case .failure(let payload) = trailingEvent {
                            throw ChatAPIError.server(message: payload.message)
                        }
                        continuation.yield(trailingEvent)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
