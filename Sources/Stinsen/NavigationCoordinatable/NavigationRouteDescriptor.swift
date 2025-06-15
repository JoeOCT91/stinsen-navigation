import Foundation
import SwiftUI

// MARK: - NavigationRouteDescriptor

/// A type-safe descriptor for navigation routes that preserves compile-time type information.
///
/// ## Design Philosophy
/// NavigationRouteDescriptor bridges the gap between compile-time type safety and runtime
/// navigation management. It captures route information in a type-safe manner while providing
/// the flexibility needed for dynamic navigation operations.
///
/// ## Architecture
/// - **Type Safety**: Preserves specific coordinator and output types
/// - **Lazy Creation**: Routes are created only when needed
/// - **Performance**: Minimal overhead through generic specialization
/// - **Flexibility**: Supports both view and coordinator outputs
///
/// ## Usage
/// ```swift
/// // Create a descriptor for a coordinator route
/// let descriptor = NavigationRouteDescriptor(
///     keyPath: \.profile,
///     presentationType: .push,
///     factory: { coordinator in
///         { input in coordinator.makeProfile(input) }
///     }
/// )
/// ```
public struct NavigationRouteDescriptor<T: NavigationCoordinatable, Output: ViewPresentable> {
    /// The keypath to the route in the coordinator
    public let keyPath: PartialKeyPath<T>

    /// How this route should be presented
    public let presentationType: PresentationType

    /// Factory closure that creates the route output
    public let factory: (T) -> (Any?) -> Output

    /// Hash of the keypath for efficient comparison
    public let keyPathHash: Int

    /// Creates a new navigation route descriptor.
    ///
    /// - Parameters:
    ///   - keyPath: The keypath to the route in the coordinator
    ///   - presentationType: How this route should be presented
    ///   - factory: Factory closure that creates the route output
    public init(
        keyPath: PartialKeyPath<T>,
        presentationType: PresentationType,
        factory: @escaping (T) -> (Any?) -> Output
    ) {
        self.keyPath = keyPath
        self.presentationType = presentationType
        self.factory = factory
        keyPathHash = keyPath.hashValue
    }

    /// Creates a navigation child item from this descriptor.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator instance
    ///   - input: Optional input parameters
    /// - Returns: A type-erased navigation child item
    public func makeItem(_ coordinator: T, input: Any? = nil) -> AnyNavigationChildItem {
        let item = NavigationChildItem<Output>(
            presentableFactory: { [factory] in
                factory(coordinator)(input)
            },
            keyPathIsEqual: { [keyPathHash] otherKeyPath in
                if let otherHash = (otherKeyPath as? PartialKeyPath<T>)?.hashValue {
                    return otherHash == keyPathHash
                }
                return false
            },
            presentationType: presentationType,
            input: input,
            keyPath: keyPathHash
        )

        return AnyNavigationChildItem(item)
    }
}

// MARK: - Protocol Conformances

extension NavigationRouteDescriptor: Identifiable {
    public var id: Int { keyPathHash }
}

extension NavigationRouteDescriptor: Equatable {
    public static func == (lhs: NavigationRouteDescriptor<T, Output>, rhs: NavigationRouteDescriptor<T, Output>) -> Bool {
        lhs.keyPathHash == rhs.keyPathHash
    }
}

extension NavigationRouteDescriptor: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyPathHash)
    }
}

// MARK: - Convenience Extensions

public extension NavigationRouteDescriptor where Output: Coordinatable {
    /// Creates a descriptor for a coordinator route without input.
    ///
    /// - Parameters:
    ///   - keyPath: The keypath to the route
    ///   - presentationType: How the route should be presented
    ///   - factory: Factory that creates the coordinator
    /// - Returns: A navigation route descriptor
    static func coordinator(
        keyPath: PartialKeyPath<T>,
        presentationType: PresentationType,
        factory: @escaping (T) -> () -> Output
    ) -> NavigationRouteDescriptor<T, Output> {
        NavigationRouteDescriptor(
            keyPath: keyPath,
            presentationType: presentationType,
            factory: { coordinator in
                { _ in factory(coordinator)() }
            }
        )
    }

    /// Creates a descriptor for a coordinator route with input.
    ///
    /// - Parameters:
    ///   - keyPath: The keypath to the route
    ///   - presentationType: How the route should be presented
    ///   - factory: Factory that creates the coordinator with input
    /// - Returns: A navigation route descriptor
    static func coordinator<Input>(
        keyPath: PartialKeyPath<T>,
        presentationType: PresentationType,
        factory: @escaping (T) -> (Input) -> Output
    ) -> NavigationRouteDescriptor<T, Output> {
        NavigationRouteDescriptor(
            keyPath: keyPath,
            presentationType: presentationType,
            factory: { coordinator in
                { input in
                    if let typedInput = input as? Input {
                        return factory(coordinator)(typedInput)
                    } else {
                        fatalError("Input type mismatch: expected \(Input.self), got \(type(of: input))")
                    }
                }
            }
        )
    }
}

public extension NavigationRouteDescriptor where Output == AnyView {
    /// Creates a descriptor for a view route without input.
    ///
    /// - Parameters:
    ///   - keyPath: The keypath to the route
    ///   - presentationType: How the route should be presented
    ///   - factory: Factory that creates the view
    /// - Returns: A navigation route descriptor
    static func view<V: View>(
        keyPath: PartialKeyPath<T>,
        presentationType: PresentationType,
        factory: @escaping (T) -> () -> V
    ) -> NavigationRouteDescriptor<T, AnyView> {
        NavigationRouteDescriptor(
            keyPath: keyPath,
            presentationType: presentationType,
            factory: { coordinator in
                { _ in AnyView(factory(coordinator)()) }
            }
        )
    }

    /// Creates a descriptor for a view route with input.
    ///
    /// - Parameters:
    ///   - keyPath: The keypath to the route
    ///   - presentationType: How the route should be presented
    ///   - factory: Factory that creates the view with input
    /// - Returns: A navigation route descriptor
    static func view<V: View, Input>(
        keyPath: PartialKeyPath<T>,
        presentationType: PresentationType,
        factory: @escaping (T) -> (Input) -> V
    ) -> NavigationRouteDescriptor<T, AnyView> {
        NavigationRouteDescriptor(
            keyPath: keyPath,
            presentationType: presentationType,
            factory: { coordinator in
                { input in
                    if let typedInput = input as? Input {
                        return AnyView(factory(coordinator)(typedInput))
                    } else {
                        fatalError("Input type mismatch: expected \(Input.self), got \(type(of: input))")
                    }
                }
            }
        )
    }
}
