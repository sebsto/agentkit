#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(Linux)
import Glibc
#else
import Darwin
#endif

struct JitteredBackoffRetry: RetryStrategy {
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
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.1) * exponentialDelay
        let delay = min(exponentialDelay + jitter, maxDelay)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    func shouldRetryOperation(error: Error) -> Bool {
        //FIXME:
        true
    }
}
