import Foundation
import SwiftUI

/// A protocol that defines a coordinator capable of being used as a child of NavigationCoordinatable.
///
/// ChildCoordinatable provides a specialized coordinator that shares the navigation stack with its parent
/// but can only control the stack to its own root, not beyond it. This maintains encapsulation while
/// allowing child coordinators to manage their own navigation hierarchy.
///
/// ## Key Features
/// - **Shared Stack**: The navigation stack is shared from the parent coordinator
/// - **Limited Control**: Child can only control stack elements from its root downward
/// - **Type Safety**: Maintains strong typing with associated types
/// - **Customization**: Supports view customization like NavigationCoordinatable
///
/// ## Usage Example
/// ```swift
/// final class DetailCoordinator: ChildCoordinatable {
///     typealias Parent = MainCoordinator
///     weak var parent: MainCoordinator?
///
///     var stack: [NavigationStackItem] { parent?.stack.value ?? [] }
///     var root: NavigationStackItem { /* root item */ }
///
///     func customize(_ view: PresentedView) -> some View {
///         view
///             .tint(.blue)
///             .navigationBarTitleDisplayMode(.inline)
///     }
/// }
/// ```
public protocol ChildCoordinatable: Coordinatable {
    /// The parent coordinator type that this child belongs to
    associatedtype Parent: NavigationCoordinatable & ChildDismissable

    /// Weak reference to the parent coordinator to avoid retain cycles
    var parent: Parent? { get set }

    /// The shared navigation stack from the parent coordinator
    /// This provides read access to the full stack for navigation awareness
    var stack: [NavigationStackItem] { get }

    /// The root path that identifies this child coordinator in the navigation stack
    /// This is a partial path that corresponds to a function that creates the root view
    var rootPath: PartialKeyPath<Self> { get }

    /// The root navigation item that defines the boundary of this child coordinator's control
    /// The child can only control stack elements from this root downward
    var root: NavigationStackItem { get }

    /// The customized view type that this coordinator can produce
    associatedtype CustomizeViewType: View

    /// Customizes the appearance of views within this child coordinator's scope
    ///
    /// This function allows you to apply styling, inject environment objects, or modify
    /// the view hierarchy for all screens managed by this child coordinator.
    ///
    /// - Parameter view: The input view to be customized (using PresentedView from ViewPresentable)
    /// - Returns: The modified view with applied customizations
    func customize(_ view: PresentedView) -> CustomizeViewType
}

// MARK: - Default Implementations

public extension ChildCoordinatable {
    /// Default implementation that returns the stack from the parent coordinator
    var stack: [NavigationStackItem] {
        return parent?.stack.value ?? []
    }

    /// Default implementation that creates the root view using the rootPath
    func view() -> some View {
        // Use the rootPath to get the view property and return it
        let keyPath = rootPath
        if let viewProperty = self[keyPath: keyPath] as? any View {
            return AnyView(viewProperty)
        } else {
            fatalError("rootPath must point to a property that returns a View")
        }
    }

    /// Default implementation returns the view unchanged.
    ///
    /// Override this method to apply styling, inject environment objects,
    /// or modify the view hierarchy for all screens managed by this child coordinator.
    func customize(_ view: PresentedView) -> some View {
        return view
    }

    /// Default implementation that finds this coordinator's root item in the parent's stack
    var root: NavigationStackItem {
        // Find the stack item that represents this child coordinator using rootPath
        guard let parent = parent,
              let rootItem = parent.stack.value.first(where: { item in
                  item.keyPath == rootPath.hashValue
              }) else {
            fatalError("ChildCoordinatable root not found in parent stack. Ensure the child is properly added to the navigation stack.")
        }
        return rootItem
    }

    /// Finds the index of this child coordinator's root in the navigation stack
    /// - Returns: The index of the root item, or nil if not found
    var rootIndex: Int? {
        return stack.firstIndex { $0.id == root.id }
    }

    /// Returns the portion of the stack that this child coordinator controls
    /// This includes the root item and everything after it
    var controlledStack: [NavigationStackItem] {
        guard let rootIndex = rootIndex else { return [] }
        return Array(stack[rootIndex...])
    }

    /// Checks if this child coordinator can control the given stack item
    /// - Parameter item: The navigation stack item to check
    /// - Returns: True if the item is within this coordinator's control scope
    func canControl(_ item: NavigationStackItem) -> Bool {
        guard let rootIndex = rootIndex else { return false }
        guard let itemIndex = stack.firstIndex(where: { $0.id == item.id }) else { return false }
        return itemIndex >= rootIndex
    }

    /// Pops the navigation stack back to this child coordinator's root
    /// This is similar to popToRoot but respects the child's boundaries
    /// - Parameter action: Optional closure to execute after popping to child root
    func popToChildRoot(_ action: (() -> Void)? = nil) {
        guard let parent = parent,
              let rootIndex = rootIndex else {
            action?()
            return
        }

        // Only pop if there are items beyond the root
        if stack.count > rootIndex + 1 {
            let targetStack = Array(stack[0 ... rootIndex])
            parent.stack.value = targetStack
        }

        action?()
    }

    /// Focuses on a specific item within this child coordinator's controlled stack
    /// - Parameter predicate: Predicate to find the target item
    /// - Returns: True if the focus operation was successful
    @discardableResult
    func focusWithinScope(_ predicate: (NavigationStackItem) -> Bool) -> Bool {
        guard let parent = parent,
              let rootIndex = rootIndex else { return false }

        // Only search within the controlled stack
        let controlledItems = controlledStack
        guard let targetItem = controlledItems.first(where: predicate),
              let targetIndex = stack.firstIndex(where: { $0.id == targetItem.id }) else {
            return false
        }

        // Ensure we don't go beyond our root
        let focusIndex = max(targetIndex, rootIndex)
        let newStack = Array(stack[0 ... focusIndex])
        parent.stack.value = newStack

        return true
    }

    /// Default implementation for parent property from Coordinatable protocol
    /// Maps the typed parent to the generic ChildDismissable parent
    weak var parent: ChildDismissable? {
        get { return self.parent as? ChildDismissable }
        set { self.parent = newValue as? Parent }
    }

    /// Default implementation for dismissChild from Coordinatable protocol
    /// Forwards dismissal requests to the parent coordinator
    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        parent?.dismissChild(coordinator: coordinator, action: action)
    }
}
