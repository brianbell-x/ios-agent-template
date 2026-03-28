import Foundation

protocol ChatAPIClient {
    func streamReply(for request: BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>
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

                    var parser = ServerSentEventParser()
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

private struct ServerSentEventParser {
    private var eventName = "message"
    private var dataLines: [String] = []
    private let decoder = JSONDecoder()

    mutating func consume(line: String) throws -> ChatStreamEvent? {
        if line.isEmpty {
            return try flush()
        }

        if line.hasPrefix("event:") {
            eventName = Self.value(from: line, prefixLength: 6)
        } else if line.hasPrefix("data:") {
            dataLines.append(Self.value(from: line, prefixLength: 5))
        }

        return nil
    }

    mutating func finish() throws -> ChatStreamEvent? {
        try flush()
    }

    private mutating func flush() throws -> ChatStreamEvent? {
        defer {
            eventName = "message"
            dataLines.removeAll(keepingCapacity: true)
        }

        guard !dataLines.isEmpty else {
            return nil
        }

        let payload = dataLines.joined(separator: "\n")
        let data = Data(payload.utf8)

        switch eventName {
        case "conversation.started":
            return .conversationStarted(try decoder.decode(ConversationStartedPayload.self, from: data))
        case "message.delta":
            return .messageDelta(try decoder.decode(MessageDeltaPayload.self, from: data))
        case "agent.updated":
            return .agentUpdated(try decoder.decode(AgentUpdatedPayload.self, from: data))
        case "run.item":
            return .runItem(try decoder.decode(RunItemPayload.self, from: data))
        case "message.completed":
            return .messageCompleted(try decoder.decode(MessageCompletedPayload.self, from: data))
        case "error":
            return .failure(try decoder.decode(StreamErrorPayload.self, from: data))
        case "done":
            return .done
        default:
            return nil
        }
    }

    private static func value(from line: String, prefixLength: Int) -> String {
        var value = String(line.dropFirst(prefixLength))
        if value.first == " " {
            value.removeFirst()
        }
        return value
    }
}
