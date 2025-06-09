import Foundation
import Combine
import SwiftUI

/// Enhanced navigation stack that bridges legacy coordinator pattern with SwiftUI NavigationStack
///
/// This class maintains backwards compatibility while providing modern navigation features:
/// - Automatic path management for push navigation
/// - Separate handling of sheets and full screen covers
/// - Observable state for SwiftUI integration
public class NavigationStack<T: NavigationCoordinatable>: ObservableObject {

    // MARK: - Legacy Properties (Unchanged)

    /// Actions to execute when views are dismissed
    var dismissalAction: [Int: () -> Void] = [:]

    /// Reference to parent coordinator for hierarchical navigation
    weak var parent: ChildDismissable?

    /// Publisher that emits when navigation pops to a specific index
    var poppedTo = PassthroughSubject<Int, Never>()

    /// Initial route keyPath
    let initial: PartialKeyPath<T>

    /// Initial input data
    let initialInput: Any?

    /// Root navigation item
    var root: NavigationRoot!

    // MARK: - Core Navigation State

    /// Main navigation stack array (source of truth)
    /// - Note: When this changes, it automatically updates the SwiftUI navigation state
    @Published var value: [NavigationStackItem] {
        didSet {
            updateNavigationState()
        }
    }

    // MARK: - SwiftUI Navigation Bridge

    /// Navigation path for push-style navigation
    /// - Note: Only contains items with presentationType.isPush
    @Published var navigationPath: [NavigationStackItem] = []

    /// Current sheet presentation
    /// - Note: Only one sheet can be presented at a time
    @Published var sheetItem: NavigationStackItem?

    /// Current full screen cover presentation
    /// - Note: Only one full screen cover can be presented at a time
    @Published var fullScreenCoverItem: NavigationStackItem?

    // MARK: - Initialization

    /// Creates a new navigation stack
    /// - Parameters:
    ///   - initial: The initial route keyPath
    ///   - initialInput: Optional input data for the initial route
    public init(initial: PartialKeyPath<T>, _ initialInput: Any? = nil) {
        self.value = []
        self.initial = initial
        self.initialInput = initialInput
        self.root = nil
    }

    // MARK: - Private Methods

    /// Updates SwiftUI navigation state based on the current stack value
    /// This method separates different presentation types for SwiftUI's navigation system
    private func updateNavigationState() {
        // Extract push navigations for NavigationStack path
        navigationPath = value.filter { $0.presentationType == .push }

//        // Find the last modal presentation (only one can be shown at a time)
//        sheetItem = value.last { $0.presentationType == .modal }
//
//        // Find the last full screen presentation (only one can be shown at a time)
//        fullScreenCoverItem = value.last { $0.presentationType == .fullScreen }
    }

    // MARK: - Public Methods

    /// Removes all items from the navigation stack
    public func removeAll() {
        value.removeAll()
        dismissalAction.removeAll()
    }

    /// Pops navigation to a specific route
    /// - Parameter keyPathHash: The hash of the route to pop to
    public func popTo(_ keyPathHash: Int) {
        if let index = value.firstIndex(where: { $0.keyPath == keyPathHash }) {
            // Remove all items after the target
            value.removeSubrange((index + 1)...)
            // Notify observers
            poppedTo.send(keyPathHash)
        }
    }
}

// MARK: - NavigationStack Extensions

/// Convenience methods for checking navigation state
public extension NavigationStack {
    /// The hash of the route at the top of the stack
    /// - Returns: The hash of the current route or -1 if stack is empty
    var currentRoute: Int {
        value.last?.keyPath ?? -1
    }

    /// Checks if a particular route is in the stack
    /// - Parameter keyPathHash: The hash of the keyPath to check
    /// - Returns: Boolean indicating whether the route is in the stack
    func isInStack(_ keyPathHash: Int) -> Bool {
        value.contains { $0.keyPath == keyPathHash }
    }

    /// Checks if this coordinator has a parent
    /// - Returns: Boolean indicating whether the coordinator has a parent
    func hasParent() -> Bool {
        parent != nil
    }
}
