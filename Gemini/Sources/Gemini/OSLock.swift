import Foundation
import os

final class OSLock: NSLocking {
    private var osLock = os_unfair_lock_s()

    func lock() {
        os_unfair_lock_lock(&osLock)
    }

    func unlock() {
        os_unfair_lock_unlock(&osLock)
    }

    func whileLocked<T>(do work: () -> T) -> T {
        lock(); defer { unlock() }
        return work()
    }
}
