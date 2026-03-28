import Foundation

enum ChatRole: String, Codable, Equatable {
    case user
    case assistant
}

enum ChatMessageState: String, Codable, Equatable {
    case complete
    case streaming
    case failed
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    var text: String
    let createdAt: Date
    var state: ChatMessageState

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        createdAt: Date = .now,
        state: ChatMessageState = .complete
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.state = state
    }
}

struct ConversationSnapshot: Codable, Equatable {
    var conversationID: String?
    var activeAgentName: String
    var messages: [ChatMessage]
}

struct BackendChatRequest: Encodable {
    let message: String
    let conversationID: String?
    let agentID: String?

    enum CodingKeys: String, CodingKey {
        case message
        case conversationID = "conversation_id"
        case agentID = "agent_id"
    }
}

struct ConversationStartedPayload: Decodable, Equatable {
    let conversationID: String
    let agentID: String
    let sessionHistoryLimit: Int

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case agentID = "agent_id"
        case sessionHistoryLimit = "session_history_limit"
    }
}

struct MessageDeltaPayload: Decodable, Equatable {
    let delta: String
}

struct AgentUpdatedPayload: Decodable, Equatable {
    let agentName: String

    enum CodingKeys: String, CodingKey {
        case agentName = "agent_name"
    }
}

struct RunItemPayload: Decodable, Equatable {
    let name: String
    let itemType: String

    enum CodingKeys: String, CodingKey {
        case name
        case itemType = "item_type"
    }
}

struct MessageCompletedPayload: Decodable, Equatable {
    let conversationID: String
    let agentID: String
    let finalAgentName: String
    let responseID: String?
    let content: String
    let sessionHistoryLimit: Int

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case agentID = "agent_id"
        case finalAgentName = "final_agent_name"
        case responseID = "response_id"
        case content
        case sessionHistoryLimit = "session_history_limit"
    }
}

struct StreamErrorPayload: Decodable, Equatable {
    let code: String
    let message: String
}

struct ConversationStatusPayload: Decodable, Equatable {
    let conversationID: String
    let exists: Bool
    let sessionHistoryLimit: Int

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case exists
        case sessionHistoryLimit = "session_history_limit"
    }
}

enum ChatStreamEvent: Equatable {
    case conversationStarted(ConversationStartedPayload)
    case messageDelta(MessageDeltaPayload)
    case agentUpdated(AgentUpdatedPayload)
    case runItem(RunItemPayload)
    case messageCompleted(MessageCompletedPayload)
    case failure(StreamErrorPayload)
    case done
}
