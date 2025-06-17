import Foundation
import SwiftUI

/// Errors that can occur with child coordinators
public enum ChildCoordinatorError: Error, LocalizedError {
    case rootNotFound
    case parentNotSet

    public var errorDescription: String? {
        switch self {
        case .rootNotFound:
            return "Child coordinator root not found in navigation stack"
        case .parentNotSet:
            return "Child coordinator parent is not set"
        }
    }
}

// MARK: - ChildRoot Property Wrapper

/// Property wrapper for child coordinator root routes
/// Usage: @ChildRoot(makeMainView) var root
@propertyWrapper public struct ChildRoot<C: ChildCoordinatable, Input, Output: ViewPresentable> {
    private let closure: (C) -> (Input) -> Output
    private let rootManager: ChildRootManager<C>

    public var wrappedValue: ChildRouteAction<C, Input, Output> {
        return ChildRouteAction(.push, closure: closure) // Default to push for root
    }

    // MARK: - Initializers for Views

    /// Creates a child root for Views without input (Void)
    public init<ViewOutput: View>(
        _ closureValue: @escaping (C) -> () -> ViewOutput
    ) where Input == Void, Output == AnyView {
        let adaptedClosure: (C) -> (Input) -> Output = { coordinator in { (_: Input) in AnyView(closureValue(coordinator)()) } }
        closure = adaptedClosure
        rootManager = ChildRootManager()

        // Set up the root closure for the manager
        let rootClosure: (C) -> AnyView = { coordinator in
            AnyView(closureValue(coordinator)())
        }
        rootManager.setRootClosure(rootClosure)
        rootManager.setKeyPath(ObjectIdentifier(type(of: closureValue)).hashValue)
    }

    /// Creates a child root for Views with input
    public init<ViewOutput: View>(
        _ closureValue: @escaping (C) -> (Input) -> ViewOutput
    ) where Output == AnyView {
        let adaptedClosure: (C) -> (Input) -> Output = { coordinator in { input in AnyView(closureValue(coordinator)(input)) } }
        closure = adaptedClosure
        rootManager = ChildRootManager()

        // Set up the root closure for the manager (using Void input for root)
        let rootClosure: (C) -> AnyView = { _ in
            // For root views, we need to handle the case where Input might not be Void
            // This is a limitation - root views should typically not require input
            fatalError("Root views with input parameters are not supported. Use Void input for root views.")
        }
        rootManager.setRootClosure(rootClosure)
        rootManager.setKeyPath(ObjectIdentifier(type(of: closureValue)).hashValue)
    }

    // MARK: - Initializers for Coordinators

    /// Creates a child root for Coordinators without input (Void)
    public init(
        _ closureValue: @escaping (C) -> () -> Output
    ) where Input == Void, Output: Coordinatable {
        let adaptedClosure: (C) -> (Input) -> Output = { coordinator in { (_: Input) in closureValue(coordinator)() } }
        closure = adaptedClosure
        rootManager = ChildRootManager()

        // Set up the root closure for the manager
        let rootClosure: (C) -> AnyView = { coordinator in
            let output = closureValue(coordinator)()
            // For coordinators, we need to get their view
            return AnyView(output.view())
        }
        rootManager.setRootClosure(rootClosure)
        rootManager.setKeyPath(ObjectIdentifier(type(of: closureValue)).hashValue)
    }

    /// Creates a child root for Coordinators with input
    public init(
        _ closureValue: @escaping (C) -> (Input) -> Output
    ) where Output: Coordinatable {
        closure = closureValue
        rootManager = ChildRootManager()

        // Set up the root closure for the manager (using Void input for root)
        let rootClosure: (C) -> AnyView = { _ in
            // For root coordinators, we need to handle the case where Input might not be Void
            // This is a limitation - root coordinators should typically not require input
            fatalError("Root coordinators with input parameters are not supported. Use Void input for root coordinators.")
        }
        rootManager.setRootClosure(rootClosure)
        rootManager.setKeyPath(ObjectIdentifier(type(of: closureValue)).hashValue)
    }

    /// Provides access to the root manager
    public var projectedValue: ChildRootManager<C> {
        return rootManager
    }

    /// Creates the root view for the coordinator
    func createView(for coordinator: C) -> AnyView where Input == Void {
        let output = closure(coordinator)(())
        if let view = output as? any View {
            return AnyView(view)
        } else if let anyView = output as? AnyView {
            return anyView
        } else {
            fatalError("ChildRoot must produce a View or AnyView")
        }
    }
}

/// Manager class for child coordinator root state
public class ChildRootManager<C: ChildCoordinatable>: ObservableObject {
    /// The root navigation item that defines the boundary of this child coordinator's control
    @Published private(set) var item: NavigationStackItem?

    /// The key path hash that identifies this child coordinator's root
    private(set) var keyPath: Int = 0

    /// The closure to create the root view
    private var rootClosure: ((C) -> AnyView)?

    init() {
        item = nil
    }

    /// Sets the keyPath for this root manager
    func setKeyPath(_ keyPath: Int) {
        self.keyPath = keyPath
    }

    /// Sets the root closure for creating views
    func setRootClosure(_ closure: @escaping (C) -> AnyView) {
        rootClosure = closure
    }

    /// Creates the root view for the coordinator
    func createView(for coordinator: C) -> AnyView {
        guard let rootClosure = rootClosure else {
            fatalError("Root closure not set. Make sure to access the @ChildRoot property first.")
        }
        return rootClosure(coordinator)
    }

    /// Updates the root item if it matches this child's keyPath
    /// - Parameter stackItem: The potential root item
    /// - Returns: True if the item was set as the root
    @discardableResult
    func updateRoot(from stackItem: NavigationStackItem) -> Bool {
        if stackItem.keyPath == keyPath {
            item = stackItem
            return true
        }
        return false
    }

    /// Safely gets the root item
    /// - Returns: The root item if available, nil otherwise
    var safeRoot: NavigationStackItem? {
        return item
    }

    /// Gets the root item, throwing an error if not available
    /// - Returns: The root item
    /// - Throws: ChildCoordinatorError if root is not set
    func getRoot() throws -> NavigationStackItem {
        guard let item = item else {
            throw ChildCoordinatorError.rootNotFound
        }
        return item
    }
}

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
/// - **Safe Root Access**: Uses @ChildRoot property wrapper for safe root item management
///
/// ## Usage Example
/// ```swift
/// final class DetailCoordinator: ChildCoordinatable {
///     typealias Parent = MainCoordinator
///     weak var parent: MainCoordinator?
///
///     @ChildRoot(makeMainView) var root
///     @ChildRoute(.push) var detailView = makeDetailView
///
///     func makeMainView() -> some View {
///         MainView()
///     }
///
///     func makeDetailView() -> some View {
///         DetailView()
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

    /// Gets the root manager for this child coordinator
    /// This should typically be implemented by accessing the projectedValue of a @ChildRoot property
    var rootManager: ChildRootManager<Self> { get }
}

// MARK: - Default Implementations

public extension ChildCoordinatable {
    /// Default implementation that returns the stack from the parent coordinator
    var stack: [NavigationStackItem] {
        return parent?.stack.value ?? []
    }

    /// Default implementation that creates the view using ChildRoot
    func view() -> some View {
        return rootManager.createView(for: self)
    }

    /// Default implementation returns the view unchanged.
    ///
    /// Override this method to apply styling, inject environment objects,
    /// or modify the view hierarchy for all screens managed by this child coordinator.
    func customize(_ view: PresentedView) -> some View {
        return view
    }

    /// Safely gets the root navigation item
    /// - Returns: The root item if available, nil otherwise
    var safeRoot: NavigationStackItem? {
        return rootManager.safeRoot
    }

    /// Finds the index of this child coordinator's root in the navigation stack
    /// - Returns: The index of the root item, or nil if not found
    var rootIndex: Int? {
        guard let root = safeRoot else { return nil }
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

    /// Updates the child root by searching the parent's stack
    /// This should be called when the child coordinator is added to the navigation stack
    func updateChildRoot() {
        guard let parent = parent else { return }

        // Search for our root in the parent's stack
        for stackItem in parent.stack.value {
            if rootManager.updateRoot(from: stackItem) {
                break
            }
        }
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
