import Combine
import Foundation
import SwiftUI

/// A type-safe wrapper for ViewPresentable that preserves associated type information.
///
/// This wrapper allows us to store different types of presentables in collections
/// while maintaining access to their specific associated types when needed.
/// It provides a bridge between the type-safe world of specific presentables
/// and the type-erased world of collections.
struct TypeSafePresentableWrapper {
    /// The type-erased presentable for collection storage
    private let _presentable: any ViewPresentable

    /// Type-safe view creation closure that preserves the original associated type
    private let _createView: () -> AnyView

    /// Initializes a wrapper with a specific presentable type.
    ///
    /// This initializer captures the presentable's specific type and creates
    /// a closure that can recreate the view without additional type erasure.
    ///
    /// - Parameter presentable: The specific presentable to wrap
    init<P: ViewPresentable>(_ presentable: P) {
        _presentable = presentable
        _createView = { AnyView(presentable.view()) }
    }

    /// Returns the type-erased presentable for compatibility with existing code.
    var presentable: any ViewPresentable {
        return _presentable
    }

    /// Creates the view using the preserved type information.
    ///
    /// This method uses the captured closure to create the view without
    /// additional type erasure beyond what's necessary for AnyView.
    ///
    /// - Returns: The presentable's view wrapped in AnyView
    func createView() -> AnyView {
        return _createView()
    }
}

/// A wrapper around the root navigation item that provides observable behavior.
///
/// NavigationRoot serves as the observable container for the initial route in a
/// navigation coordinator. It ensures that changes to the root item trigger
/// SwiftUI view updates through the `@Published` property wrapper.
///
/// ## Usage
/// This class is typically managed internally by NavigationStack and should not
/// be instantiated directly by application code.
public class NavigationRoot: ObservableObject {
    /// The root navigation item that defines the initial route.
    ///
    /// Changes to this property trigger SwiftUI view updates for any views
    /// observing this NavigationRoot instance.
    @Published var item: NavigationRootItem

    /// Initializes a new NavigationRoot with the specified root item.
    ///
    /// - Parameter item: The NavigationRootItem that represents the initial route
    init(item: NavigationRootItem) {
        self.item = item
    }
}

/// Represents the root item in a navigation hierarchy.
///
/// NavigationRootItem contains all the information needed to render the initial
/// route of a navigation coordinator, including the route identifier, input parameters,
/// and the presentable content.
///
/// ## Properties
/// - `keyPath`: Unique identifier derived from the route's KeyPath hash
/// - `input`: Optional input parameters passed to the root route
/// - `child`: The presentable content (view or coordinator) for the root
struct NavigationRootItem {
    /// Unique identifier for this root item, derived from the route's KeyPath hash
    let keyPath: Int

    /// Optional input parameters passed to the root route creation closure
    let input: Any?

    /// The type-safe presentable wrapper that preserves associated type information
    let childWrapper: TypeSafePresentableWrapper

    /// Computed property for backward compatibility
    var child: any ViewPresentable {
        return childWrapper.presentable
    }

    /// Initializes a NavigationRootItem with type-safe presentable wrapping.
    ///
    /// - Parameters:
    ///   - keyPath: Unique identifier for the root item
    ///   - input: Optional input parameters
    ///   - child: The presentable content to wrap
    init<P: ViewPresentable>(keyPath: Int, input: Any?, child: P) {
        self.keyPath = keyPath
        self.input = input
        childWrapper = TypeSafePresentableWrapper(child)
    }
}

/// Represents an item in the navigation stack with type-safe presentable content.
///
/// NavigationStackItem encapsulates all information needed to present a single
/// navigation destination, including its presentation type, content, and metadata.
/// Items are used by PresentationHelper to determine how to present content
/// (push, modal, or full-screen).
///
/// ## Key Features
/// - **Type-safe identification**: Uses KeyPath hash for unique identification
/// - **Presentation type awareness**: Knows how it should be presented
/// - **Input parameter storage**: Maintains reference to creation parameters
/// - **SwiftUI compatibility**: Conforms to Identifiable and Hashable
/// - **Associated type preservation**: Maintains type information where possible
struct NavigationStackItem {
    /// The presentation type that determines how this item should be displayed
    let presentationType: PresentationType

    /// The type-safe presentable wrapper that preserves associated type information
    let presentableWrapper: TypeSafePresentableWrapper

    /// Unique identifier derived from the route's KeyPath hash
    let keyPath: Int

    /// Optional input parameters passed to the route creation closure
    let input: Any?

    /// Computed property for backward compatibility
    var presentable: any ViewPresentable {
        return presentableWrapper.presentable
    }

    /// Initializes a NavigationStackItem with type-safe presentable wrapping.
    ///
    /// - Parameters:
    ///   - presentationType: How this item should be presented
    ///   - presentable: The presentable content to wrap
    ///   - keyPath: Unique identifier for the item
    ///   - input: Optional input parameters
    init<P: ViewPresentable>(
        presentationType: PresentationType,
        presentable: P,
        keyPath: Int,
        input: Any?
    ) {
        self.presentationType = presentationType
        presentableWrapper = TypeSafePresentableWrapper(presentable)
        self.keyPath = keyPath
        self.input = input
    }
}

// MARK: - NavigationStackItem Conformance

extension NavigationStackItem: Identifiable, Hashable {
    /// Unique identifier for SwiftUI list and navigation operations
    var id: Int { keyPath }

    /// Equality comparison based on keyPath for efficient stack operations
    ///
    /// Two NavigationStackItems are considered equal if they have the same keyPath,
    /// regardless of their input parameters or presentation type. This allows for
    /// efficient stack manipulation and duplicate detection.
    ///
    /// - Parameters:
    ///   - lhs: Left-hand side NavigationStackItem
    ///   - rhs: Right-hand side NavigationStackItem
    /// - Returns: `true` if both items have the same keyPath, `false` otherwise
    static func == (lhs: NavigationStackItem, rhs: NavigationStackItem) -> Bool {
        return lhs.keyPath == rhs.keyPath
    }

    /// Hash implementation for Set and Dictionary operations
    ///
    /// Uses the keyPath as the primary hash component, ensuring that items
    /// with the same route have the same hash value for efficient collection operations.
    ///
    /// - Parameter hasher: The hasher to combine values into
    func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
    }
}

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
    /// The root is lazily initialized when first accessed through the `root` property
    /// or explicitly set up via `ensureRoot(with:)`.
    private var _root: NavigationRoot?

    /// Initializes a new NavigationStack with the specified initial route.
    ///
    /// Creates an empty navigation stack configured to use the specified route
    /// as its root when first presented. The root is not created until explicitly
    /// requested through `ensureRoot(with:)`.
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
    /// this property, typically through `ensureRoot(with:)`.
    ///
    /// - Returns: The NavigationRoot instance for this stack
    /// - Throws: Fatal error if accessed before root initialization
    var root: NavigationRoot {
        if let root = _root {
            return root
        }
        fatalError("Root must be set before accessing. Call ensureRoot(with:) first.")
    }

    /// Ensures the root navigation item is initialized with the specified coordinator.
    ///
    /// Creates the root NavigationRoot instance if it doesn't already exist, using
    /// the initial route and input parameters specified during NavigationStack creation.
    /// This method is idempotent and safe to call multiple times.
    ///
    /// - Parameter coordinator: The coordinator instance to use for root creation
    ///
    /// ## Implementation Details
    /// 1. Checks if root already exists (early return if so)
    /// 2. Attempts to get NavigationOutputable from the route
    /// 3. Falls back to accessing transition from @Root property wrapper via reflection
    /// 4. Constructs NavigationRootItem with route metadata
    /// 5. Wraps in NavigationRoot for observable behavior
    func ensureRoot(with coordinator: T) {
        guard _root == nil else { return }

        let routeValue = coordinator[keyPath: initial]
        let presentable: any ViewPresentable

        // Try to cast to NavigationOutputable (for @NavigationRoute)
        if let transition = routeValue as? NavigationOutputable {
            presentable = transition.using(coordinator: coordinator, input: initialInput as Any)
        } else {
            // Fallback for @Root property wrapper
            // We need to access the transition property from the Root property wrapper
            // Since KeyPath only gives us the wrappedValue, we'll use reflection to find the wrapper
            let transition = findRootTransition(in: coordinator, for: initial)
            presentable = transition.using(coordinator: coordinator, input: initialInput as Any)
        }

        let rootItem = NavigationRootItem(
            keyPath: initial.hashValue,
            input: initialInput,
            child: presentable
        )

        _root = NavigationRoot(item: rootItem)
    }

    /// Finds the transition from a @Root property wrapper using reflection.
    private func findRootTransition(in coordinator: T, for keyPath: PartialKeyPath<T>) -> NavigationOutputable {
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
