import BedrockService
import Testing

@testable import AgentKit

@Suite("Conversation Manager Tests")
struct ConversationManagerTests {

    // MARK: - Test Helpers

    func createMessage(role: Role, text: String) -> Message {
        Message(from: role, content: [.text(text)])
    }

    func createHistory(messages: [Message]) -> History {
        History(messages)
    }

    // MARK: - NullConversationManager Tests

    @Suite("NullConversationManager")
    struct NullConversationManagerTests {

        @Test("applyManagement returns unchanged history")
        func applyManagementReturnsUnchangedHistory() async throws {
            var manager = NullConversationManager()
            let messages = [
                Message(from: .user, content: [.text("Hello")]),
                Message(from: .assistant, content: [.text("Hi there!")]),
            ]
            let history = History(messages)

            let result = try await manager.applyManagement(history: history)

            #expect(result.count == 2)
            #expect(result.first?.role == .user)
            #expect(result.last?.role == .assistant)
        }

        @Test("reduceContext returns empty history")
        func reduceContextReturnsEmptyHistory() async throws {
            var manager = NullConversationManager()
            let messages = [
                Message(from: .user, content: [.text("Hello")]),
                Message(from: .assistant, content: [.text("Hi there!")]),
            ]
            let history = History(messages)

            let result = try await manager.reduceContext(history: history)

            #expect(result.isEmpty)
        }

        @Test("removedMessageCount always returns zero")
        func removedMessageCountAlwaysReturnsZero() {
            let manager = NullConversationManager()
            #expect(manager.removedMessageCount() == 0)
        }
    }

    // MARK: - SlidingWindowConversationManager Tests

    @Suite("SlidingWindowConversationManager")
    struct SlidingWindowConversationManagerTests {

        @Test("applyManagement keeps messages within window size")
        func applyManagementKeepsMessagesWithinWindowSize() async throws {
            var manager = SlidingWindowConversationManager(windowSize: 3)
            let messages = [
                Message(from: .user, content: [.text("Message 1")]),
                Message(from: .assistant, content: [.text("Response 1")]),
                Message(from: .user, content: [.text("Message 2")]),
                Message(from: .assistant, content: [.text("Response 2")]),
                Message(from: .user, content: [.text("Message 3")]),
            ]
            let history = History(messages)

            let result = try await manager.applyManagement(history: history)

            #expect(result.count == 3)
            #expect(manager.removedMessageCount() == 2)
        }

        @Test("applyManagement preserves recent messages")
        func applyManagementPreservesRecentMessages() async throws {
            var manager = SlidingWindowConversationManager(windowSize: 2)
            let messages = [
                Message(from: .user, content: [.text("Old message")]),
                Message(from: .assistant, content: [.text("Old response")]),
                Message(from: .user, content: [.text("Recent message")]),
                Message(from: .assistant, content: [.text("Recent response")]),
            ]
            let history = History(messages)

            let result = try await manager.applyManagement(history: history)

            #expect(result.count == 2)
            let resultArray = Array(result)
            if case .text(let text) = resultArray[0].content.first {
                #expect(text == "Recent message")
            }
            if case .text(let text) = resultArray[1].content.first {
                #expect(text == "Recent response")
            }
        }

        @Test("reduceContext removes half of messages")
        func reduceContextRemovesHalfOfMessages() async throws {
            var manager = SlidingWindowConversationManager(windowSize: 10)
            let messages = [
                Message(from: .user, content: [.text("Message 1")]),
                Message(from: .assistant, content: [.text("Response 1")]),
                Message(from: .user, content: [.text("Message 2")]),
                Message(from: .assistant, content: [.text("Response 2")]),
            ]
            let history = History(messages)

            let result = try await manager.reduceContext(history: history)

            #expect(result.count == 2)
        }

        @Test("windowSize of zero returns empty history")
        func windowSizeOfZeroReturnsEmptyHistory() async throws {
            var manager = SlidingWindowConversationManager(windowSize: 0)
            let messages = [
                Message(from: .user, content: [.text("Message")]),
                Message(from: .assistant, content: [.text("Response")]),
            ]
            let history = History(messages)

            let result = try await manager.applyManagement(history: history)

            #expect(result.isEmpty)
            #expect(manager.removedMessageCount() == 2)
        }
    }

    // MARK: - SummarizingConversationManager Tests

    @Suite("SummarizingConversationManager")
    struct SummarizingConversationManagerTests {

        @Test("applyManagement keeps messages within window size")
        func applyManagementKeepsMessagesWithinWindowSize() async throws {
            var manager = SummarizingConversationManager(
                preserveRecentMessages: 3
            )
            let messages = [
                Message(from: .user, content: [.text("Message 1")]),
                Message(from: .assistant, content: [.text("Response 1")]),
                Message(from: .user, content: [.text("Message 2")]),
                Message(from: .assistant, content: [.text("Response 2")]),
                Message(from: .user, content: [.text("Message 3")]),
            ]
            let history = History(messages)

            let result = try await manager.applyManagement(history: history)

            #expect(result.count >= 3)  // Should preserve recent messages
        }

        @Test("reduceContext creates summary with mock agent")
        func reduceContextCreatesSummaryWithMockAgent() async throws {
            let mockAgent = MockAgent()
            var manager = SummarizingConversationManager(
                preserveRecentMessages: 2,
                summarizationAgent: mockAgent
            )
            let messages = [
                Message(from: .user, content: [.text("Hello world")]),
                Message(from: .assistant, content: [.text("Hi there!")]),
                Message(from: .user, content: [.text("How are you?")]),
                Message(from: .assistant, content: [.text("I'm doing well!")]),
            ]
            let history = History(messages)

            let result = try await manager.reduceContext(history: history)

            #expect(result.count >= 3)  // Should have summary + preserved messages
            #expect(mockAgent.callCount == 1)
            if case .text(let summaryText) = result.first?.content.first {
                #expect(summaryText.contains("Previous conversation summary"))
                #expect(summaryText.contains("Mock summary"))
            }
        }

        @Test("reduceContext creates summary without agent")
        func reduceContextCreatesSummaryWithoutAgent() async throws {
            var manager = SummarizingConversationManager(
                preserveRecentMessages: 2
            )
            let messages = [
                Message(from: .user, content: [.text("Hello world")]),
                Message(from: .assistant, content: [.text("Hi there!")]),
                Message(from: .user, content: [.text("How are you?")]),
                Message(from: .assistant, content: [.text("I'm doing well!")]),
            ]
            let history = History(messages)

            let result = try await manager.reduceContext(history: history)

            #expect(result.count >= 3)  // Should have summary + preserved messages
            if case .text(let summaryText) = result.first?.content.first {
                #expect(summaryText.contains("Previous conversation summary"))
            }
        }

        @Test("removedMessageCount tracks removed messages")
        func removedMessageCountTracksRemovedMessages() async throws {
            var manager = SummarizingConversationManager(
                preserveRecentMessages: 2
            )
            let messages = [
                Message(from: .user, content: [.text("Message 1")]),
                Message(from: .assistant, content: [.text("Response 1")]),
                Message(from: .user, content: [.text("Message 2")]),
                Message(from: .assistant, content: [.text("Response 2")]),
                Message(from: .user, content: [.text("Message 3")]),
            ]
            let history = History(messages)

            _ = try await manager.reduceContext(history: history)

            #expect(manager.removedMessageCount() == 1)  // One message was summarized
        }
    }
}

// MARK: - Mock Agent

class MockAgent: AgentProtocol {
    var callCount = 0
    var lastPrompt: String?

    func callAsFunction(_ prompt: String, callback: Agent.AgentCallbackFunction?) async throws {
        callCount += 1
        lastPrompt = prompt

        // Simulate a summary response
        callback?(.text("Mock summary of the conversation covering key topics and interactions."))
    }
}
