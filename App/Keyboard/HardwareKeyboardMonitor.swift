import Observation
import SwiftUI

#if os(iOS)
import GameController
#endif

/// Tracks whether a hardware keyboard is attached so the on-screen keyboard can hide itself.
@Observable
@MainActor
final class HardwareKeyboardMonitor {
    private(set) var isConnected: Bool

    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init() {
        #if os(iOS)
        isConnected = GCKeyboard.coalesced != nil
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isConnected = true }
            },
            center.addObserver(forName: .GCKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isConnected = GCKeyboard.coalesced != nil }
            },
        ]
        #else
        isConnected = true
        #endif
    }

    isolated deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}
