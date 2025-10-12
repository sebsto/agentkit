import BedrockService
import Logging
import MCPShared

extension Agent {

    internal func runLoop(
        prompt: String,
        systemPrompt: String,
        bedrock: BedrockService,
        model: BedrockModel,
        tools: [any ToolProtocol],
        logger: Logger,
        callback: AgentCallbackFunction? = nil
    ) async throws {

        // verify that the model supports tool usage
        guard model.hasConverseModality(.toolUse) else {
            logger.error("Model does not support converse tools", metadata: ["model": "\(model)"])
            throw AgentError.modelNotSupported(model)
        }

        // variables we're going to reuse for the duration of the conversation
        var requestBuilder: ConverseRequestBuilder? = nil

        // convert Tools to Bedrock Tools
        let bedrockTools = try tools.bedrockTools()

        // is it our first request ?
        if requestBuilder == nil {
            requestBuilder = try ConverseRequestBuilder(with: model)
                .withHistory(getHistory())
                .withPrompt(prompt)

            if bedrockTools.count > 0 {
                requestBuilder = try requestBuilder!.withTools(bedrockTools)
            }

            if !systemPrompt.isEmpty {
                requestBuilder = try requestBuilder!.withSystemPrompt(systemPrompt)
            }
        } else {
            // if not, we can just add the prompt to the existing request builder
            requestBuilder = try ConverseRequestBuilder(from: requestBuilder!)
                .withHistory(getHistory())
        }

        // add the prompt to the history
        appendToHistory(Message(prompt))

        // loop on calling the model while the last message is NOT text
        // in other words, has long as we receive toolUse, call the tool, call the model again and iterate until the lats message is text.
        // TODO : how to manage reasoning ?
        var lastMessageIsText = false
        repeat {
            logger.trace("Calling ConverseStream")
            let reply = try await bedrock.converseStream(with: requestBuilder!)
            
            // read the stream of elements
            logger.trace("Reading stream of elements")
            for try await element: ConverseStreamElement in reply.stream {

                // read the stream of elements.  If this is a text content, print it.
                // otherwise, collect the message.
                switch element {
                case .text(_, let text):
                    if let callback {
                        callback(.text(text))
                    } else {
                        print(text, terminator: "")
                    }
                case .toolUse(_, let toolUse):
                    logger.trace("Tool Use", metadata: ["toolUse": "\(toolUse.name)"])
                    if let callback {
                        callback(.toolUse(toolUse))
                    }
                case .messageComplete(let message):
                    self.appendToHistory(message)
                    if let callback {
                        callback(.message(message))
                    } else {
                        if message.hasTextContent() {
                            print("\n")
                        }
                    }
                case .metaData(let metadata):
                    logger.trace("Metadata", metadata: ["metadata": "\(metadata)"])
                    if let callback {
                        callback(.metaData(metadata))
                    }
                default:
                    break
                }
            }

            // If the last message is toolUse, invoke the tool and
            // continue the conversation with the tool result.
            logger.debug("Have receive a complete message, checking is this is tool use?")
            if let msg = self.lastMessageFromHistory(),
                let toolUse = msg.getToolUse()
            {

                logger.trace("Last message", metadata: ["message": "\(msg)"])
                logger.debug("Yes, let's use a tool", metadata: ["toolUse": "\(toolUse.name)"])

                // find the tool and call it
                requestBuilder = try await resolveToolUse(
                    bedrock: bedrock,
                    requestBuilder: requestBuilder!,
                    tools: tools,
                    toolUse: toolUse,
                    messages: self.getHistory(),
                    logger: logger
                )

                // add the tool result to the history
                if let toolResult = requestBuilder?.toolResult {
                    logger.debug("Tool Result", metadata: ["result": "\(toolResult)"])
                    self.appendToHistory(Message(toolResult))
                } else {
                    logger.warning("No tool result found, this is unexpected")
                }

            } else {
                logger.debug("No, checking if the last message is text")
                if self.lastMessageFromHistory()?.hasTextContent() == true {
                    lastMessageIsText = true
                    logger.debug("yes, exiting the loop ")
                } else {
                    logger.warning("Last message is not text nor tool use, break out the loop")
                    logger.debug(
                        "Last message",
                        metadata: ["message": "\(String(describing: self.lastMessageFromHistory()))"]
                    )
                    lastMessageIsText = false
                }
            }
        } while lastMessageIsText == false

        if let callback {
            callback(.end)
        }
    }
}
