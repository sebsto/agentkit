extension Agent {

    fileprivate struct UnsafeTransferBox<Value>: @unchecked Sendable {
        let value: Value

        init(value: Value) {
            // init(value: sending Value) {
            self.value = value
        }
    }

    /// Stream events from an agent asynchronously.
    ///
    /// - Parameter message: The message to send to the agent.
    /// - Returns: An async throwing stream of events from the agent.
    public func streamAsync(_ message: String) -> AsyncThrowingStream<AgentCallbackEvent, Error> {

        // wrap Self in a unchecked Sendable box
        // we know the transfer is safe here because the mutating property of  Agent is
        // History and it is protected by a Mutex
        let transferBox = UnsafeTransferBox(value: self)
        return AsyncThrowingStream(AgentCallbackEvent.self) { continuation in
            let t = Task {
                do {
                    try await transferBox.value(message) { event in
                        if case .end = event {
                            continuation.finish()
                        }
                        continuation.yield(event)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                t.cancel()
            }
        }
    }
}
