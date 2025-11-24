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
        ragSystem: RAG?,
        logger: Logger,
        callback: AgentCallbackFunction? = nil
    ) async throws {

        // verify that the model supports tool usage
        guard model.hasConverseModality(.toolUse) else {
            logger.error("Model does not support converse tools", metadata: ["model": "\(model)"])
            throw AgentError.modelNotSupported(model)
        }

        // variables we're going to reuse for the duration of the loop
        var requestBuilder: ConverseRequestBuilder? = nil

        // convert Tools to Bedrock Tools
        let bedrockTools = try tools.bedrockTools()

        // is it our first request in this loop ?
        if requestBuilder == nil {
            requestBuilder = try ConverseRequestBuilder(with: model)
                .withHistory(getHistory())
                .withPrompt(prompt)

            if bedrockTools.count > 0 {
                requestBuilder = try requestBuilder!.withTools(bedrockTools)
            }

            // do we need to make a RAG call ?
            var ragContext: String? = nil
            if let ragSystem  {
                let context = try await self.retrieve(ragSystem: ragSystem, query: prompt, maxResult: 3)
                ragContext = """
Relevant context from knowledge base:
\(context)
Use this context to inform your responses when relevant.
"""
            }

            // prepare the system prompt
            let sysPrompt = "\(systemPrompt)\n\(ragContext ?? "")"
            if !systemPrompt.isEmpty || ragContext != nil {
                requestBuilder = try requestBuilder!.withSystemPrompt(sysPrompt)
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

            // define a simple retry strategy, with three attemps and we'll not retry authentication errors
            let nonRetryableError = BedrockLibraryError.authenticationFailed("")
            let retryStrategy = SimpleRetry(maxAttempts: 3, nonRetryableError: [nonRetryableError])

            // Invoke the model until it passes or fails
            let result = try await invokeModelWithRetry(strategy: retryStrategy, logger: self.logger) {
                attempt in

                do {

                    logger.debug("Calling ConverseStream")
                    return try await bedrock.converseStream(with: requestBuilder!)

                } catch let error as BedrockLibraryError {

                    if case .inputTooLong(let msg) = error {
                        logger.debug(
                            "Input too long, reducing context",
                            metadata: [
                                "error": "\(msg)",
                                "history_size": "\(getHistory().count)",
                                "retryCounter": "\(attempt)",
                            ]
                        )

                        // compact the history
                        let compactedHistory = try await self.conversationManager.reduceContext(
                            history: self.getHistory()
                        )
                        logger.debug("History compacted", metadata: ["history_size": "\(compactedHistory.count)"])
                        self.setHistory(history: compactedHistory)

                        // create a new request with the compacted history
                        requestBuilder = try ConverseRequestBuilder(from: requestBuilder!)
                            .withHistory(getHistory())
                            .withPrompt(prompt)
                    }
                    // rethrow the error and let the retry happen
                    throw error
                }
            }

            guard case let .success(reply) = result else {
                if case let .failure(error) = result {
                    throw error
                } else {
                    fatalError("Can not happen")
                }
            }

            // read the stream of elements
            logger.debug("Reading stream of elements")
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

                    // collect token usage for stats and cleanup
                    if let inputTokens = metadata.usage?.inputTokens {
                        self.inputTokenCount += inputTokens
                    }
                    if let outputTokens = metadata.usage?.outputTokens {
                        self.outputTokenCount += outputTokens
                    }

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

            // compact the history, according to the defined strategy
            let compactedHistory = try await self.conversationManager.applyManagement(history: self.getHistory())
            self.setHistory(history: compactedHistory)

        } while lastMessageIsText == false

        if let callback {
            callback(.end)
        }
    }
}
