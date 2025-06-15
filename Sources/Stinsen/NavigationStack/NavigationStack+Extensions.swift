import Foundation

// MARK: - NavigationStack Convenience Methods

/// Convenience methods for inspecting navigation stack contents.
public extension NavigationStack {
    /// The hash of the route at the top of the navigation stack.
    ///
    /// Provides quick access to the identifier of the currently visible route.
    /// Returns -1 if the stack is empty (only root is visible).
    ///
    /// - Returns: The KeyPath hash of the top route, or -1 if stack is empty
    ///
    /// ## Usage
    /// ```swift
    /// if coordinator.stack.currentRoute == \.settings.hashValue {
    ///     print("Settings is currently visible")
    /// }
    /// ```
    var currentRoute: Int {
        return value.last?.keyPath ?? -1
    }

    /// Checks if a particular route is present anywhere in the navigation stack.
    ///
    /// Searches the entire navigation stack for an item with the specified
    /// KeyPath hash, regardless of its position in the stack.
    ///
    /// - Parameter keyPathHash: The hash of the KeyPath to search for
    /// - Returns: `true` if the route is found in the stack, `false` otherwise
    ///
    /// ## Usage
    /// ```swift
    /// if coordinator.stack.isInStack(\.profile.hashValue) {
    ///     print("Profile is somewhere in the navigation stack")
    /// }
    /// ```
    func isInStack(_ keyPathHash: Int) -> Bool {
        return value.contains { $0.keyPath == keyPathHash }
    }

    /// Checks if this coordinator has a parent coordinator.
    ///
    /// Determines whether this coordinator is a child of another coordinator
    /// in the navigation hierarchy. Root coordinators typically don't have parents.
    ///
    /// - Returns: `true` if the coordinator has a parent, `false` otherwise
    ///
    /// ## Usage
    /// ```swift
    /// if coordinator.stack.hasParent() {
    ///     // This is a child coordinator
    ///     coordinator.dismissCoordinator()
    /// }
    /// ```
    func hasParent() -> Bool {
        return parent != nil
    }
}
