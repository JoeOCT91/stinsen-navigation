import SwiftUI

/// A protocol that defines view creation for navigation stack items.
///
/// NavigationViewFactory abstracts the creation of SwiftUI views from NavigationStackItem instances,
/// providing a clean separation between navigation logic and view creation concerns.
/// This design follows the factory pattern to encapsulate view creation complexity.
///
/// ## Design Goals
/// - **Separation of Concerns**: Keep navigation logic separate from view creation
/// - **Testability**: Enable easy mocking of view creation for unit tests
/// - **Extensibility**: Allow custom view creation strategies
/// - **Type Safety**: Maintain strong typing while abstracting creation logic
///
/// ## Usage
/// ```swift
/// let factory = DefaultNavigationViewFactory()
/// let view = factory.createDestinationContent(for: stackItem)
/// ```
public protocol NavigationViewFactory {
    /// Creates a SwiftUI view for a regular destination (non-coordinator) navigation stack item.
    ///
    /// This method handles the creation of views for regular SwiftUI views that are
    /// pushed onto the navigation stack. It delegates to the item's presentable wrapper
    /// to create the actual view content.
    ///
    /// - Parameter item: The navigation stack item to create a view for
    /// - Returns: A SwiftUI view representing the destination content
    ///
    /// ## Implementation Notes
    /// - Should handle all non-coordinator presentables
    /// - Must preserve the original view's type information through the wrapper
    /// - Should be efficient and avoid unnecessary view recreations
    func createDestinationContent(for item: NavigationStackItem) -> AnyView

    /// Creates a SwiftUI view for a coordinator navigation stack item.
    ///
    /// This method handles the creation of views for coordinator presentables that are
    /// pushed onto the navigation stack. It determines the appropriate view creation
    /// strategy based on the coordinator type (NavigationCoordinatable vs other types).
    ///
    /// - Parameter item: The navigation stack item containing a coordinator
    /// - Returns: A SwiftUI view representing the coordinator content
    ///
    /// ## Implementation Notes
    /// - Should distinguish between NavigationCoordinatable and other coordinator types
    /// - Must handle the coordinator's view() method invocation properly
    /// - Should respect coordinator boundaries and lifecycle
    func createCoordinatorContent(for item: NavigationStackItem) -> AnyView
}

/// Default implementation of NavigationViewFactory.
///
/// DefaultNavigationViewFactory provides the standard view creation logic that was
/// previously embedded in PresentationHelper. It maintains the same behavior but
/// encapsulates it in a dedicated, testable component.
///
/// ## Architecture
/// The factory creates lightweight wrapper views that delegate to the actual
/// presentable's view creation methods, preserving type safety while providing
/// a unified interface.
///
/// ## Performance
/// - Minimal overhead through efficient wrapper views
/// - Lazy view creation preserves performance characteristics
/// - Direct delegation to presentable wrappers avoids extra abstractions
public struct DefaultNavigationViewFactory: NavigationViewFactory {
    /// Creates the default navigation view factory.
    ///
    /// This initializer is provided for completeness and future extensibility,
    /// though the current implementation doesn't require configuration.
    public init() { }

    public func createDestinationContent(for item: NavigationStackItem) -> AnyView {
        return AnyView(DestinationContentView(item: item))
    }

    public func createCoordinatorContent(for item: NavigationStackItem) -> AnyView {
        return AnyView(CoordinatorContentView(item: item))
    }
}

// MARK: - Private View Implementations

/// A private view that renders destination content for navigation stack items.
///
/// DestinationContentView is a lightweight wrapper that delegates view creation
/// to the NavigationStackItem's presentable wrapper. This maintains the same
/// performance characteristics as the original implementation.
private struct DestinationContentView: View {
    /// The navigation stack item containing the presentable to render
    let item: NavigationStackItem

    /// The view body that creates the actual content
    ///
    /// Delegates directly to the item's presentable wrapper, which handles
    /// the type-safe view creation process. This preserves the original
    /// view's type information and creation semantics.
    var body: some View {
        item.presentableWrapper.createView()
    }
}

/// A private view that renders coordinator content for navigation stack items.
///
/// CoordinatorContentView handles the creation of views for coordinator presentables,
/// providing the same logic that was previously in PresentationHelper but now
/// encapsulated in a dedicated component.
private struct CoordinatorContentView: View {
    /// The navigation stack item containing the coordinator to render
    let item: NavigationStackItem

    /// The view body that creates the coordinator content
    ///
    /// Determines the appropriate view creation strategy based on the coordinator type.
    /// NavigationCoordinatable coordinators get special handling, while other types
    /// fall back to standard destination content creation.
    var body: some View {
        Group {
            if item.presentable is (any NavigationCoordinatable) {
                // NavigationCoordinatable coordinators create their own independent view
                item.presentableWrapper.createView()
            } else {
                // Other coordinator types use destination content logic
                item.presentableWrapper.createView()
            }
        }
    }
}

// MARK: - Factory Registry

/// A registry for managing navigation view factories.
///
/// NavigationViewFactoryRegistry provides a centralized way to manage and
/// access navigation view factories throughout the application. This enables
/// dependency injection and customization of view creation behavior.
///
/// ## Usage
/// ```swift
/// // Use default factory
/// let factory = NavigationViewFactoryRegistry.shared.factory
///
/// // Register custom factory
/// NavigationViewFactoryRegistry.shared.register(customFactory)
/// ```
public final class NavigationViewFactoryRegistry {
    /// Shared instance for global access
    public static let shared = NavigationViewFactoryRegistry()

    /// The currently registered factory
    private var _factory: NavigationViewFactory = DefaultNavigationViewFactory()

    /// Thread-safe access queue
    private let queue = DispatchQueue(label: "NavigationViewFactoryRegistry.queue", attributes: .concurrent)

    /// Private initializer to enforce singleton pattern
    private init() { }

    /// The current navigation view factory
    ///
    /// Provides thread-safe access to the currently registered factory.
    /// Defaults to DefaultNavigationViewFactory if no custom factory is registered.
    public var factory: NavigationViewFactory {
        queue.sync { _factory }
    }

    /// Registers a new navigation view factory
    ///
    /// Replaces the current factory with the provided one. This method is thread-safe
    /// and can be called from any queue.
    ///
    /// - Parameter factory: The new factory to register
    ///
    /// ## Usage
    /// ```swift
    /// // Register a custom factory for testing
    /// NavigationViewFactoryRegistry.shared.register(MockNavigationViewFactory())
    /// ```
    public func register(_ factory: NavigationViewFactory) {
        queue.async(flags: .barrier) {
            self._factory = factory
        }
    }
}
