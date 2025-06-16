import Combine
import Foundation
import SwiftUI

/// Manages navigation dismissals at the root NavigationStack level.
///
/// RootNavigationManager is responsible for handling all navigation dismissals
/// that occur through SwiftUI's NavigationStack, ensuring that coordinator stacks
/// are properly synchronized when users dismiss views through swipe gestures,
/// navigation buttons, or other SwiftUI navigation mechanisms.
///
/// This manager should be used at the root level of the navigation hierarchy
/// to coordinate dismissals across all child coordinators.
public class RootNavigationManager: ObservableObject {
    /// Shared instance for global navigation management
    public static let shared = RootNavigationManager()

    /// Dictionary of active presentation helpers keyed by coordinator ID
    private var presentationHelpers: [ObjectIdentifier: Any] = [:]

    /// Lock to ensure thread-safe access to presentation helpers
    private let helpersLock = NSLock()

    private init() { }

    /// Registers a presentation helper for dismissal management
    public func register<T: NavigationCoordinatable>(helper: PresentationHelper<T>, for coordinator: T) {
        helpersLock.lock()
        defer { helpersLock.unlock() }

        let coordinatorId = ObjectIdentifier(coordinator)
        presentationHelpers[coordinatorId] = helper

        #if DEBUG
            print("🔧 RootNavigationManager: Registered helper for \(type(of: coordinator))")
        #endif
    }

    /// Unregisters a presentation helper
    public func unregister<T: NavigationCoordinatable>(coordinator: T) {
        helpersLock.lock()
        defer { helpersLock.unlock() }

        let coordinatorId = ObjectIdentifier(coordinator)
        presentationHelpers.removeValue(forKey: coordinatorId)

        #if DEBUG
            print("🔧 RootNavigationManager: Unregistered helper for \(type(of: coordinator))")
        #endif
    }

    /// Handles coordinator dismissal at the root level
    public func handleCoordinatorDismissal<T: NavigationCoordinatable>(for coordinator: T) {
        helpersLock.lock()
        let coordinatorId = ObjectIdentifier(coordinator)
        let helper = presentationHelpers[coordinatorId] as? PresentationHelper<T>
        helpersLock.unlock()

        guard let helper = helper else {
            #if DEBUG
                print("⚠️ RootNavigationManager: No helper found for coordinator dismissal")
            #endif
            return
        }

        helper.handleCoordinatorDismissal()
    }

    /// Handles push path changes at the root level
    public func handlePushPathChange<T: NavigationCoordinatable>(
        _ newPath: [NavigationStackItem],
        for coordinator: T
    ) {
        helpersLock.lock()
        let coordinatorId = ObjectIdentifier(coordinator)
        let helper = presentationHelpers[coordinatorId] as? PresentationHelper<T>
        helpersLock.unlock()

        guard let helper = helper else {
            #if DEBUG
                print("⚠️ RootNavigationManager: No helper found for push path change")
            #endif
            return
        }

        helper.handlePushPathChange(newPath)
    }
}
