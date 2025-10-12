import Logging

internal func invokeModelWithRetry<T>(
    strategy: RetryStrategy = SimpleRetry(maxAttempts: 3),
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
                "Retrying operation",
                metadata: ["error": "\(error)", "retryCounter": "\(retryCounter)"]
            )
            retryCounter += 1
            lastError = error
            await strategy.delayBeforeRetry(attempt: retryCounter)
            //TODO: check if the error is retryable
        }
    }

    guard lastError == nil else {
        return .failure(Agent.AgentError.maxRetriesExceeded(lastError))
    }
    return .success(result)
}