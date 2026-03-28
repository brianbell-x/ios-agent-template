import Foundation
import XCTest
@testable import ChatStreamSupport

final class ChatStreamParserTests: XCTestCase {
    func testParserConsumesSharedFixture() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "shared")
            .appending(path: "chat-stream-fixture.sse")

        let contents = try String(contentsOf: fixtureURL, encoding: .utf8)
        var parser = ChatStreamParser()
        var events: [ChatStreamEvent] = []

        for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            if let event = try parser.consume(line: String(line)) {
                events.append(event)
            }
        }

        if let trailingEvent = try parser.finish() {
            events.append(trailingEvent)
        }

        XCTAssertEqual(
            events,
            [
                .conversationStarted(
                    ConversationStartedPayload(
                        conversationID: "demo-conversation",
                        agentID: "default",
                        sessionHistoryLimit: 40
                    )
                ),
                .messageDelta(MessageDeltaPayload(delta: "Hello")),
                .agentUpdated(AgentUpdatedPayload(agentName: "Planning Specialist")),
                .runItem(RunItemPayload(name: "tool_called", itemType: "tool_call_item")),
                .messageCompleted(
                    MessageCompletedPayload(
                        conversationID: "demo-conversation",
                        agentID: "default",
                        finalAgentName: "Planning Specialist",
                        responseID: "resp_demo_123",
                        content: "Hello streamed",
                        sessionHistoryLimit: 40
                    )
                ),
                .done,
            ]
        )
    }
}
