import Foundation

struct ChatStreamParser {
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
