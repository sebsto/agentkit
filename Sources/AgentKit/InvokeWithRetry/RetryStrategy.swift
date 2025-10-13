protocol RetryStrategy {
    func shouldRetry(attempt: Int, error: Error?) -> Bool
    func delayBeforeRetry(attempt: Int) async
    func shouldRetryOperation(error: Error) -> Bool

}

// MARK: - Simple Retry
struct SimpleRetry<E: Error & Equatable>: RetryStrategy {
    let maxAttempts: Int
    let nonRetryableError: [E]

    func shouldRetry(attempt: Int, error: Error?) -> Bool {
        if attempt == 1 {
            return true
        } else {
            return attempt <= maxAttempts && error != nil
        }
    }

    func delayBeforeRetry(attempt: Int) async {
        // No delay
    }

    func shouldRetryOperation(error: Error) -> Bool {
        guard let typedError = error as? E else { return true }
        // guard let nonRetryableError else { return true}
        return !nonRetryableError.contains(typedError)
    }
}
