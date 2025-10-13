import Logging

internal func invokeModelWithRetry<T>(
    strategy: RetryStrategy,
    logger: Logger,
    closure: (Int) async throws -> T
) async throws -> Result<T, Error> {

    var result: T!
    var retryCounter = 1
    var lastError: Error? = nil
    while strategy.shouldRetry(attempt: retryCounter, error: lastError) {
        do {
            result = try await closure(retryCounter)
            lastError = nil
        } catch {
            logger.debug(
                "Error caught in InvokeWithRetry",
                metadata: ["error": "\(error)", "retryCounter": "\(retryCounter)"]
            )

            await strategy.delayBeforeRetry(attempt: retryCounter)

            if strategy.shouldRetryOperation(error: error) {
                logger.trace("Retrying operation")
                lastError = error
            } else {
                logger.trace("Abond and report the error")
                return .failure(error)
            }
        }
        retryCounter += 1
    }

    guard lastError == nil else {
        return .failure(Agent.AgentError.maxRetriesExceeded(lastError))
    }
    return .success(result)
}
