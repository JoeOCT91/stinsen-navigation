import SwiftUI

// MARK: - Generic NavigationChildItem

/// A performance-optimized navigation item that uses generics to eliminate existential type overhead.
///
/// ## Design Philosophy
/// This implementation prioritizes performance by using generics at the individual item level,
/// avoiding the runtime overhead of `any ViewPresentable` existential containers.
///
/// ## Architecture
/// - **Generic Core**: `NavigationChildItem<Presentable>` - Zero runtime type overhead
/// - **Type Erasure**: `AnyNavigationChildItem` - Only used for collections when necessary
/// - **Lazy Loading**: Presentables are created on-demand for memory efficiency
///
/// ## Performance Benefits
/// - **Compile-time specialization**: Swift optimizes each generic instantiation
/// - **Direct dispatch**: No dynamic method calls through existential containers
/// - **Memory efficiency**: No boxing overhead for type information
/// - **Cache-friendly**: Better CPU cache utilization with concrete types
///
/// ## Usage
/// ```swift
/// // Create a strongly-typed navigation item
/// let item = NavigationChildItem<SomeCoordinator>(
///     presentableFactory: { SomeCoordinator() },
///     keyPathIsEqual: { $0 as? KeyPath == someKeyPath },
///     presentationType: .push,
///     input: someInput
/// )
///
/// // Access the presentable (lazy-loaded)
/// let coordinator = item.presentable
/// ```
public struct NavigationChildItem<Presentable: ViewPresentable> {
    /// The lazily-loaded presentable instance. Created on first access.
    private var _presentable: Presentable?

    /// Factory closure that creates the presentable when needed.
    /// This enables lazy loading for better memory usage and startup performance.
    private let presentableFactory: () -> Presentable

    /// Unique identifier for this navigation item. Used for SwiftUI list diffing and equality.
    let id = UUID()

    /// Closure that determines if a given keypath matches this navigation item's route.
    /// Used by focus operations to locate the correct item.
    let keyPathIsEqual: (Any) -> Bool

    /// The presentation type for this navigation item (push, modal, fullScreen).
    let presentationType: PresentationType

    /// Input parameters passed to this navigation item.
    let input: Any?

    /// KeyPath hash for route identification.
    let keyPath: Int

    /// Creates a new navigation item with the specified configuration.
    ///
    /// - Parameters:
    ///   - presentableFactory: Lazy factory for creating the navigation content
    ///   - keyPathIsEqual: Predicate for matching route keypaths
    ///   - presentationType: How this item should be presented
    ///   - input: Input parameters for the presentable
    ///   - keyPath: Hash of the route keypath
    init(
        presentableFactory: @escaping () -> Presentable,
        keyPathIsEqual: @escaping (Any) -> Bool,
        presentationType: PresentationType,
        input: Any?,
        keyPath: Int
    ) {
        self.presentableFactory = presentableFactory
        self.keyPathIsEqual = keyPathIsEqual
        self.presentationType = presentationType
        self.input = input
        self.keyPath = keyPath
    }

    /// The presentable content for this navigation item.
    ///
    /// ## Lazy Loading
    /// The presentable is created only when first accessed, providing:
    /// - **Faster startup**: Items not initially visible aren't created
    /// - **Memory efficiency**: Unused items don't consume resources
    /// - **Better performance**: Reduces object graph complexity
    ///
    /// ## Thread Safety
    /// This property should only be accessed from the main thread,
    /// as it modifies internal state and creates UI components.
    ///
    /// - Returns: The strongly-typed presentable instance
    var presentable: Presentable {
        mutating get {
            if _presentable == nil {
                _presentable = presentableFactory()
            }
            return _presentable!
        }
    }
}

// MARK: - Type-Erased Wrapper

/// A type-erased wrapper for `NavigationChildItem` that enables heterogeneous collections.
///
/// ## Why Type Erasure?
/// While `NavigationChildItem<T>` provides excellent performance through generics, we need
/// a way to store different navigation types in the same collection. `AnyNavigationChildItem`
/// solves this by erasing the generic type parameter while preserving the interface.
///
/// ## Performance Strategy
/// - **Minimal erasure**: Only the presentable access is type-erased
/// - **Direct access**: Other properties (id, presentationType, etc.) have no overhead
/// - **Lazy type erasure**: Type erasure happens only when accessing presentable
///
/// ## Memory Layout
/// ```
/// NavigationChildItem<CoordinatorA>  ────┐
/// NavigationChildItem<CoordinatorB>  ────┼─── Array<AnyNavigationChildItem>
/// NavigationChildItem<ViewC>         ────┘
/// ```
///
/// ## Usage
/// ```swift
/// // Create from generic item
/// let genericItem = NavigationChildItem<MyCoordinator>(...)
/// let erasedItem = AnyNavigationChildItem(genericItem)
///
/// // Store in collections
/// let allItems: [AnyNavigationChildItem] = [
///     AnyNavigationChildItem(homeItem),
///     AnyNavigationChildItem(profileItem),
///     AnyNavigationChildItem(settingsItem)
/// ]
/// ```
public struct AnyNavigationChildItem {
    /// Type-erased presentable accessor. This is the only operation that incurs
    /// existential type overhead, and only when the presentable is actually accessed.
    private let _presentable: () -> any ViewPresentable

    /// Direct storage for non-generic properties (zero overhead)
    private let _id: UUID
    private let _keyPathIsEqual: (Any) -> Bool
    private let _presentationType: PresentationType
    private let _input: Any?
    private let _keyPath: Int

    /// Creates a type-erased wrapper from a strongly-typed navigation item.
    ///
    /// ## Performance Notes
    /// - The generic `item` is captured by value, preserving performance benefits
    /// - Type erasure only occurs at the collection boundary
    /// - Individual operations remain optimized until presentable access
    ///
    /// - Parameter item: The strongly-typed navigation item to wrap
    init<P: ViewPresentable>(_ item: NavigationChildItem<P>) {
        var mutableItem = item
        _presentable = { mutableItem.presentable }
        _id = item.id
        _keyPathIsEqual = item.keyPathIsEqual
        _presentationType = item.presentationType
        _input = item.input
        _keyPath = item.keyPath
    }

    // MARK: - Public Interface

    /// Unique identifier for this navigation item.
    public var id: UUID { _id }

    /// Predicate for matching route keypaths.
    var keyPathIsEqual: (Any) -> Bool { _keyPathIsEqual }

    /// The presentation type for this navigation item.
    var presentationType: PresentationType { _presentationType }

    /// Input parameters for this navigation item.
    var input: Any? { _input }

    /// KeyPath hash for route identification.
    var keyPath: Int { _keyPath }

    /// The type-erased presentable content.
    ///
    /// ## Performance Impact
    /// This is the only operation that incurs existential type overhead.
    /// The underlying strongly-typed presentable is accessed through the closure,
    /// then type-erased to `any ViewPresentable`.
    ///
    /// ## When to Use
    /// Access this property only when you need the actual presentable instance.
    /// For navigation management and routing, use the other properties which have zero overhead.
    var presentable: any ViewPresentable {
        _presentable()
    }
}

// MARK: - Protocol Conformances

extension AnyNavigationChildItem: Identifiable { }

extension AnyNavigationChildItem: Equatable {
    public static func == (lhs: AnyNavigationChildItem, rhs: AnyNavigationChildItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension AnyNavigationChildItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
