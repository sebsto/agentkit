#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct ExponentialBackoffRetry: RetryStrategy {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    func shouldRetry(attempt: Int, error: Error?) -> Bool {
        if attempt == 1 {
            return true
        } else {
            return attempt <= maxAttempts && error != nil
        }
    }

    func delayBeforeRetry(attempt: Int) async {
        let delay = min(baseDelay * pow(2.0, Double(attempt - 1)), maxDelay)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}