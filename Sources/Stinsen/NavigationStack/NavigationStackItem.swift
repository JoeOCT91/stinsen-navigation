import Foundation
import SwiftUI

/// A type-safe navigation stack item that preserves exact type information.
///
/// This generic version maintains complete type safety for each individual
/// navigation item, avoiding all type erasure at the item level.
public struct TypeSafeNavigationStackItem<P: ViewPresentable> {
    /// The presentation type that determines how this item should be displayed
    public let presentationType: PresentationType

    /// The type-safe presentable wrapper that preserves exact type information
    public let presentableWrapper: TypeSafePresentableWrapper<P>

    /// Unique identifier derived from the route's KeyPath hash
    public let keyPath: Int

    /// Optional input parameters passed to the route creation closure
    public let input: Any?

    /// Initializes a TypeSafeNavigationStackItem with complete type preservation.
    ///
    /// - Parameters:
    ///   - presentationType: How this item should be presented
    ///   - presentable: The presentable content to wrap
    ///   - keyPath: Unique identifier for the item
    ///   - input: Optional input parameters
    public init(
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

    /// Creates the content view with complete type safety.
    @ViewBuilder
    public func buildContent() -> some View {
        presentableWrapper.buildView()
    }
}

/// A type-safe navigation stack that maintains homogeneous type collections.
///
/// This approach uses generics to maintain type safety within each collection
/// while providing flexibility for different navigation contexts.
public struct TypeSafeNavigationStack<T: NavigationCoordinatable, P: ViewPresentable> {
    /// Array of type-safe navigation items
    private let items: [TypeSafeNavigationStackItem<P>]

    /// Initializes a type-safe navigation stack.
    public init(_ items: [TypeSafeNavigationStackItem<P>] = []) {
        self.items = items
    }

    /// Access item by index
    public subscript(index: Int) -> TypeSafeNavigationStackItem<P>? {
        guard index >= 0, index < items.count else { return nil }
        return items[index]
    }

    /// Number of items in the stack
    public var count: Int {
        return items.count
    }

    /// Iterate over items
    public func forEach(_ body: (TypeSafeNavigationStackItem<P>) -> Void) {
        items.forEach(body)
    }

    /// Create a new stack with an additional item
    public func appending(_ item: TypeSafeNavigationStackItem<P>) -> TypeSafeNavigationStack<T, P> {
        var newItems = items
        newItems.append(item)
        return TypeSafeNavigationStack<T, P>(newItems)
    }
}

/// A heterogeneous navigation container that uses protocol dispatch.
///
/// This allows different presentable types to coexist in the same navigation
/// context while maintaining as much type safety as possible.
public protocol NavigationStackContainer {
    associatedtype Content: View

    var presentationType: PresentationType { get }
    var keyPath: Int { get }
    var input: Any? { get }

    @ViewBuilder
    func buildContent() -> Content
}

/// Concrete implementation of NavigationStackContainer.
public struct ConcreteNavigationStackContainer<P: ViewPresentable>: NavigationStackContainer {
    public let presentationType: PresentationType
    public let keyPath: Int
    public let input: Any?

    private let item: TypeSafeNavigationStackItem<P>

    public init(_ item: TypeSafeNavigationStackItem<P>) {
        self.item = item
        presentationType = item.presentationType
        keyPath = item.keyPath
        input = item.input
    }

    @ViewBuilder
    public func buildContent() -> some View {
        item.buildContent()
    }
}

/// A navigation stack that can hold different presentable types using containers.
public struct HeterogeneousNavigationStack<T: NavigationCoordinatable> {
    /// Array of navigation containers that can hold different types
    private let containers: [ConcreteNavigationStackContainer<AnyView>]

    /// Initializes a heterogeneous navigation stack.
    public init() {
        containers = []
    }

    private init(_ containers: [ConcreteNavigationStackContainer<AnyView>]) {
        self.containers = containers
    }

    /// Add a new item to the stack
    public func appending<P: ViewPresentable>(
        _ item: TypeSafeNavigationStackItem<P>
    ) -> HeterogeneousNavigationStack<T> {
        var newContainers = containers
        // Convert to AnyView for storage while preserving the container pattern
        let anyViewItem = TypeSafeNavigationStackItem<AnyView>(
            presentationType: item.presentationType,
            presentable: AnyView(item.presentableWrapper.createView()),
            keyPath: item.keyPath,
            input: item.input
        )
        newContainers.append(ConcreteNavigationStackContainer(anyViewItem))
        return HeterogeneousNavigationStack<T>(newContainers)
    }

    /// Number of items in the stack
    public var count: Int {
        return containers.count
    }

    /// Build content for all items
    @ViewBuilder
    public func buildAllContent() -> some View {
        ForEach(0 ..< containers.count, id: \.self) { index in
            if let container = containers[safe: index] {
                container.buildContent()
            }
        }
    }

    /// Get container at index
    public subscript(index: Int) -> ConcreteNavigationStackContainer<AnyView>? {
        guard index >= 0, index < containers.count else { return nil }
        return containers[index]
    }
}

// MARK: - Backward Compatibility

/// Legacy navigation stack item for gradual migration.
///
/// This maintains the old interface while providing a path to migrate
/// to the new type-safe approach.
@available(*, deprecated, message: "Use TypeSafeNavigationStackItem<P> instead") public struct NavigationStackItem {
    /// The presentation type that determines how this item should be displayed
    public let presentationType: PresentationType

    /// The legacy wrapper (using LegacyPresentableWrapper)
    public let presentableWrapper: LegacyPresentableWrapper

    /// Unique identifier derived from the route's KeyPath hash
    public let keyPath: Int

    /// Optional input parameters passed to the route creation closure
    public let input: Any?

    /// Legacy initializer for backward compatibility
    init<P: ViewPresentable>(
        presentationType: PresentationType,
        presentable: P,
        keyPath: Int,
        input: Any?
    ) {
        self.presentationType = presentationType
        presentableWrapper = LegacyPresentableWrapper(presentable)
        self.keyPath = keyPath
        self.input = input
    }
}

// MARK: - Protocol Conformances

extension TypeSafeNavigationStackItem: Identifiable {
    /// Unique identifier for SwiftUI list and navigation operations
    public var id: Int { keyPath }
}

extension TypeSafeNavigationStackItem: Equatable {
    /// Equality comparison based on keyPath
    public static func == (lhs: TypeSafeNavigationStackItem<P>, rhs: TypeSafeNavigationStackItem<P>) -> Bool {
        return lhs.keyPath == rhs.keyPath
    }
}

extension TypeSafeNavigationStackItem: Hashable {
    /// Hash implementation for Set and Dictionary operations
    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
    }
}
