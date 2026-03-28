import Foundation

protocol ChatAPIClient {
    func streamReply(for request: BackendChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>
    func conversationStatus(for conversationID: String) async throws -> ConversationStatusPayload
}
