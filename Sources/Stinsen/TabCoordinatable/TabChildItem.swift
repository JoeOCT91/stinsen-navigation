//
//  TabChildItem.swift
//  Stinsen
//
//  Created by Yousef Mohamed on 14/06/2025.
//

import SwiftUI

// MARK: - Generic TabChildItem

/// A performance-optimized tab item that uses generics to eliminate existential type overhead.
///
/// ## Design Philosophy
/// This implementation prioritizes performance by using generics at the individual item level,
/// avoiding the runtime overhead of `any ViewPresentable` existential containers.
///
/// ## Architecture
/// - **Generic Core**: `TabChildItem<Presentable>` - Zero runtime type overhead
/// - **Type Erasure**: `AnyTabChildItem` - Only used for collections when necessary
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
/// // Create a strongly-typed tab item
/// let item = TabChildItem<SomeCoordinator>(
///     presentableFactory: { SomeCoordinator() },
///     keyPathIsEqual: { $0 as? KeyPath == someKeyPath },
///     tabItem: { isActive in TabItemView(active: isActive) },
///     onTapped: { isRepeat in handleTap(isRepeat) }
/// )
///
/// // Access the presentable (lazy-loaded)
/// let coordinator = item.presentable
/// ```
struct TabChildItem<Presentable: ViewPresentable> {
    /// The lazily-loaded presentable instance. Created on first access.
    private var _presentable: Presentable?

    /// Factory closure that creates the presentable when needed.
    /// This enables lazy loading for better memory usage and startup performance.
    private let presentableFactory: () -> Presentable

    /// Unique identifier for this tab item. Used for SwiftUI list diffing and equality.
    let id = UUID()

    /// Closure that determines if a given keypath matches this tab's route.
    /// Used by focus operations to locate the correct tab.
    let keyPathIsEqual: (Any) -> Bool

    /// Factory for creating the tab bar item view based on active state.
    /// - Parameter isActive: Whether this tab is currently selected
    /// - Returns: The tab bar item view (icon + text)
    let tabItem: (Bool) -> AnyView

    /// Handler called when the tab is tapped.
    /// - Parameter isRepeat: True if tapping the already-active tab
    let onTapped: (Bool) -> Void

    /// Creates a new tab item with the specified configuration.
    ///
    /// - Parameters:
    ///   - presentableFactory: Lazy factory for creating the tab's content
    ///   - keyPathIsEqual: Predicate for matching route keypaths
    ///   - tabItem: Factory for creating tab bar item views
    ///   - onTapped: Handler for tab tap events
    init(
        presentableFactory: @escaping () -> Presentable,
        keyPathIsEqual: @escaping (Any) -> Bool,
        tabItem: @escaping (Bool) -> AnyView,
        onTapped: @escaping (Bool) -> Void
    ) {
        self.presentableFactory = presentableFactory
        self.keyPathIsEqual = keyPathIsEqual
        self.tabItem = tabItem
        self.onTapped = onTapped
    }

    /// The presentable content for this tab.
    ///
    /// ## Lazy Loading
    /// The presentable is created only when first accessed, providing:
    /// - **Faster startup**: Tabs not initially visible aren't created
    /// - **Memory efficiency**: Unused tabs don't consume resources
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

/// A type-erased wrapper for `TabChildItem` that enables heterogeneous collections.
///
/// ## Why Type Erasure?
/// While `TabChildItem<T>` provides excellent performance through generics, we need
/// a way to store different tab types in the same collection. `AnyTabChildItem`
/// solves this by erasing the generic type parameter while preserving the interface.
///
/// ## Performance Strategy
/// - **Minimal erasure**: Only the presentable access is type-erased
/// - **Direct access**: Other properties (id, tabItem, etc.) have no overhead
/// - **Lazy type erasure**: Type erasure happens only when accessing presentable
///
/// ## Memory Layout
/// ```
/// TabChildItem<CoordinatorA>  ────┐
/// TabChildItem<CoordinatorB>  ────┼─── Array<AnyTabChildItem>
/// TabChildItem<ViewC>         ────┘
/// ```
///
/// ## Usage
/// ```swift
/// // Create from generic item
/// let genericItem = TabChildItem<MyCoordinator>(...)
/// let erasedItem = AnyTabChildItem(genericItem)
///
/// // Store in collections
/// let allTabs: [AnyTabChildItem] = [
///     AnyTabChildItem(homeItem),
///     AnyTabChildItem(profileItem),
///     AnyTabChildItem(settingsItem)
/// ]
/// ```
struct AnyTabChildItem {
    /// Type-erased presentable accessor. This is the only operation that incurs
    /// existential type overhead, and only when the presentable is actually accessed.
    private let _presentable: () -> any ViewPresentable

    /// Direct storage for non-generic properties (zero overhead)
    private let _id: UUID
    private let _keyPathIsEqual: (Any) -> Bool
    private let _tabItem: (Bool) -> AnyView
    private let _onTapped: (Bool) -> Void

    /// Creates a type-erased wrapper from a strongly-typed tab item.
    ///
    /// ## Performance Notes
    /// - The generic `item` is captured by value, preserving performance benefits
    /// - Type erasure only occurs at the collection boundary
    /// - Individual operations remain optimized until presentable access
    ///
    /// - Parameter item: The strongly-typed tab item to wrap
    init<P: ViewPresentable>(_ item: TabChildItem<P>) {
        var mutableItem = item
        self._presentable = { mutableItem.presentable }
        self._id = item.id
        self._keyPathIsEqual = item.keyPathIsEqual
        self._tabItem = item.tabItem
        self._onTapped = item.onTapped
    }

    // MARK: - Public Interface

    /// Unique identifier for this tab item.
    var id: UUID { _id }

    /// Predicate for matching route keypaths.
    var keyPathIsEqual: (Any) -> Bool { _keyPathIsEqual }

    /// Factory for creating tab bar item views.
    var tabItem: (Bool) -> AnyView { _tabItem }

    /// Handler for tab tap events.
    var onTapped: (Bool) -> Void { _onTapped }

    /// The type-erased presentable content.
    ///
    /// ## Performance Impact
    /// This is the only operation that incurs existential type overhead.
    /// The underlying strongly-typed presentable is accessed through the closure,
    /// then type-erased to `any ViewPresentable`.
    ///
    /// ## When to Use
    /// Access this property only when you need the actual presentable instance.
    /// For tab bar rendering and navigation, use the other properties which have zero overhead.
    var presentable: any ViewPresentable {
        _presentable()
    }
}

// MARK: - Protocol Conformances

/// Conformance to SwiftUI protocols for use in ForEach and collections.
extension AnyTabChildItem: Identifiable, Equatable {
    /// Equality based on unique identifier.
    /// This enables efficient SwiftUI list diffing and animations.
    static func == (lhs: AnyTabChildItem, rhs: AnyTabChildItem) -> Bool {
        lhs.id == rhs.id
    }
}
