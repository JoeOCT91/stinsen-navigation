import Combine
import Foundation
import SwiftUI

/// Manages the navigation state for a NavigationCoordinatable coordinator.
///
/// NavigationStack serves as the central data model for navigation state, maintaining
/// an array of NavigationStackItems that represent the current navigation hierarchy.
/// It provides observable behavior through `@Published` properties and manages
/// dismissal actions and parent-child relationships.
///
/// ## Key Responsibilities
/// - **Stack Management**: Maintains ordered list of navigation items
/// - **Dismissal Actions**: Stores and executes cleanup closures when items are removed
/// - **Root Management**: Handles the initial route configuration
/// - **Parent-Child Relationships**: Manages coordinator hierarchy
/// - **Change Notifications**: Provides Combine publishers for stack changes
///
/// ## Usage Example
/// ```swift
/// final class HomeCoordinator: NavigationCoordinatable {
///     var stack = NavigationStack(initial: \.home)
///
///     @Route(.push) var home = makeHome
///     @Route(.modal) var settings = makeSettings
/// }
/// ```
public class NavigationStack<T: NavigationCoordinatable>: ObservableObject {
    /// The current navigation stack items in presentation order.
    ///
    /// This array represents the complete navigation state, including items with
    /// different presentation types (push, modal, fullScreen). Changes to this
    /// array trigger SwiftUI view updates and PresentationHelper state synchronization.
    @Published var value: [NavigationStackItem]

    /// Dictionary mapping route KeyPath hashes to their dismissal actions.
    ///
    /// When navigation items are removed from the stack (either programmatically
    /// or through user interaction), their corresponding dismissal actions are
    /// executed to perform cleanup operations.
    var dismissalAction: [Int: () -> Void] = [:]

    /// Publisher that emits when the stack is popped to a specific index.
    ///
    /// Emits the target index when pop operations occur, allowing coordinators
    /// and other components to react to navigation changes. Emits -1 when
    /// popped to root (empty stack).
    var poppedTo = PassthroughSubject<Int, Never>()

    /// The KeyPath to the initial route for this navigation stack.
    ///
    /// This defines which route should be used as the root of the navigation
    /// hierarchy when the coordinator is first presented.
    let initial: PartialKeyPath<T>

    /// Optional input parameters for the initial route.
    ///
    /// These parameters are passed to the initial route's creation closure
    /// when the root is established.
    let initialInput: Any?

    /// Weak reference to the parent coordinator that can dismiss this coordinator.
    ///
    /// This reference enables proper parent-child coordinator relationships
    /// and prevents retain cycles in the coordinator hierarchy.
    weak var parent: ChildDismissable?

    /// Private storage for the root navigation item.
    ///
    /// The root is lazily initialized when first accessed through the `root` property.
    private var _root: NavigationRoot?

    /// Initializes a new NavigationStack with the specified initial route.
    ///
    /// Creates an empty navigation stack configured to use the specified route
    /// as its root when first presented. The root is created lazily when first accessed.
    ///
    /// - Parameters:
    ///   - initial: KeyPath to the route that should serve as the root
    ///   - initialInput: Optional input parameters for the root route
    ///
    /// ## Example
    /// ```swift
    /// var stack = NavigationStack(initial: \.home)
    /// var stackWithInput = NavigationStack(initial: \.userProfile, user)
    /// ```
    public init(initial: PartialKeyPath<T>, _ initialInput: Any? = nil) {
        value = []
        self.initial = initial
        self.initialInput = initialInput
        _root = nil
    }

    /// The root navigation item for this stack.
    ///
    /// Provides access to the root NavigationRoot instance, which contains the
    /// initial route configuration. The root must be initialized before accessing
    /// this property via `ensureRoot(with:)`.
    ///
    /// - Returns: The NavigationRoot instance for this stack
    /// - Throws: Fatal error if accessed before root initialization
    var root: NavigationRoot {
        guard let root = _root else {
            fatalError("Root must be set before accessing. Call ensureRoot(with:) first.")
        }
        return root
    }

    /// Safely accesses the root, ensuring it's initialized first.
    ///
    /// This method ensures the root is properly initialized before returning it.
    /// It's safer than the `root` property for use during coordinator switching.
    ///
    /// - Parameter coordinator: The coordinator instance to use for root creation if needed
    /// - Returns: The NavigationRoot instance for this stack
    func safeRoot(with coordinator: T) -> NavigationRoot {
        ensureRoot(with: coordinator)
        return root
    }

    /// Ensures the root navigation item is initialized with the specified coordinator.
    ///
    /// Creates the root NavigationRoot instance if it doesn't already exist, using
    /// the initial route and input parameters specified during NavigationStack creation.
    /// This method is idempotent and safe to call multiple times - the guard ensures
    /// that root setup only happens once, even with repeated calls.
    ///
    /// - Parameter coordinator: The coordinator instance to use for root creation
    ///
    /// ## Thread Safety
    /// This method should only be called from the main thread as it modifies
    /// the `_root` property which affects UI state.
    func ensureRoot(with coordinator: T) {
        // Guard ensures setup only happens once - early return if already initialized
        guard _root == nil else {
            StinsenLogger.logWarning("NavigationStack.ensureRoot called multiple times - root already initialized", category: .navigation)
            return
        }

        StinsenLogger.logDebug("NavigationStack.ensureRoot: Initializing root for \(String(describing: T.self))", category: .navigation)

        _root = NavigationStack.createRoot(coordinator: coordinator, initial: initial, initialInput: initialInput)
    }

    /// Resets the root to allow for root switching.
    ///
    /// This method should be called when switching roots to allow for proper re-initialization.
    /// After calling this, the next access to root will trigger re-initialization.
    ///
    /// - Warning: This should only be called during root switching operations
    func resetRoot() {
        StinsenLogger.logDebug("NavigationStack.resetRoot: Clearing root for re-initialization", category: .navigation)
        _root = nil
    }

    /// Creates a NavigationRoot for the given coordinator and initial route.
    private static func createRoot(coordinator: T, initial: PartialKeyPath<T>, initialInput: Any?) -> NavigationRoot {
        let routeValue = coordinator[keyPath: initial]
        let presentable: any ViewPresentable

        // Try to cast to TypeSafeNavigationOutputable (for @NavigationRoute)
        if let transition = routeValue as? any TypeSafeNavigationOutputable {
            presentable = transition.using(coordinator: coordinator, input: initialInput as Any)
        } else {
            // Fallback for @Root property wrapper
            let transition = findRootTransition(in: coordinator, for: initial)
            presentable = transition.using(coordinator: coordinator, input: initialInput as Any)
        }

        let rootItem = NavigationRootItem(
            keyPath: initial.hashValue,
            input: initialInput,
            child: presentable
        )

        return NavigationRoot(item: rootItem)
    }

    /// Finds the transition from a @Root property wrapper using reflection.
    private static func findRootTransition(in coordinator: T, for keyPath: PartialKeyPath<T>) -> any TypeSafeNavigationOutputable {
        let mirror = Mirror(reflecting: coordinator)

        // Look for Root property wrappers in the coordinator
        for child in mirror.children {
            if let rootWrapper = child.value as? any RootTransitionProvider {
                // For now, return the first Root wrapper we find
                // This works because ensureRoot is called with a specific keyPath
                // and typically coordinators have only one or two root routes
                return rootWrapper.getTransition()
            }
        }

        fatalError("No Root property wrapper found in coordinator for keyPath: \(keyPath)")
    }

    // MARK: - Convenience Methods

    /// Returns the number of items currently in the navigation stack.
    ///
    /// This count includes all presentation types (push, modal, fullScreen) and
    /// can be used for stack depth analysis or debugging purposes.
    ///
    /// - Returns: The total number of navigation items in the stack
    var count: Int {
        return value.count
    }

    /// Indicates whether the navigation stack is empty.
    ///
    /// An empty stack means no navigation items have been pushed beyond the root.
    /// This is useful for determining if the coordinator is at its initial state.
    ///
    /// - Returns: `true` if the stack contains no items, `false` otherwise
    var isEmpty: Bool {
        return value.isEmpty
    }

    /// Returns the last (topmost) item in the navigation stack.
    ///
    /// This represents the currently active navigation item that the user sees.
    /// Returns `nil` if the stack is empty (only root is visible).
    ///
    /// - Returns: The topmost NavigationStackItem, or `nil` if stack is empty
    var last: NavigationStackItem? {
        return value.last
    }

    /// Safely accesses a navigation stack item at the specified index.
    ///
    /// Provides bounds-safe access to stack items, returning `nil` if the index
    /// is out of bounds. This prevents crashes during stack manipulation operations.
    ///
    /// - Parameter index: The zero-based index of the item to retrieve
    /// - Returns: The NavigationStackItem at the specified index, or `nil` if out of bounds
    func item(at index: Int) -> NavigationStackItem? {
        guard index >= 0 && index < value.count else { return nil }
        return value[index]
    }
}
