protocol RetryStrategy {
    func shouldRetry(attempt: Int, error: Error?) -> Bool
    func delayBeforeRetry(attempt: Int) async
}

// MARK: - Simple Retry
struct SimpleRetry: RetryStrategy {
    let maxAttempts: Int

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
}