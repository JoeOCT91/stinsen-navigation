import Foundation
import SwiftUI

// MARK: - Navigation Output Protocol

/// Type-safe protocol for creating presentables (used with generics)
public protocol TypeSafeNavigationOutputable {
    associatedtype PresentableType: ViewPresentable
    func using(coordinator: Any, input: Any) -> PresentableType
}

public protocol RouteType { }

public struct RootSwitch: RouteType { }

public struct Presentation: RouteType {
    let type: PresentationType
}

// MARK: - Type-Safe Navigation Wrapper

public class TypeSafeNavigationWrapper<ViewType: View> {
    private let createViewClosure: () -> ViewType
    private let routeTypeClosure: () -> Any
    private let outputableClosure: () -> any TypeSafeNavigationOutputable

    init<T: NavigationCoordinatable, U: RouteType, Input, Output: ViewPresentable>(
        coordinator: T,
        input: Input,
        content: NavigationContent<T, U, Input, Output>
    ) where Output.PresentedView == ViewType {
        createViewClosure = {
            let presentable = content.createPresentable(for: coordinator, input: input)
            return presentable.view()
        }
        routeTypeClosure = {
            content.getRouteType()
        }
        outputableClosure = {
            content
        }
    }

    /// Create view using preserved type information
    func createView() -> ViewType {
        return createViewClosure()
    }

    /// Get route type
    func getRouteType() -> Any {
        return routeTypeClosure()
    }

    /// Get type-safe outputable
    func getOutputable() -> any TypeSafeNavigationOutputable {
        return outputableClosure()
    }
}

// MARK: - Type-Erased Navigation Wrapper

public class AnyNavigationWrapper {
    private let createViewClosure: () -> AnyView
    private let routeTypeClosure: () -> Any
    private let outputableClosure: () -> any TypeSafeNavigationOutputable

    init<T: NavigationCoordinatable, U: RouteType, Input, Output: ViewPresentable>(
        coordinator: T,
        input: Input,
        content: NavigationContent<T, U, Input, Output>
    ) {
        createViewClosure = {
            let presentable = content.createPresentable(for: coordinator, input: input)
            return AnyView(presentable.view())
        }
        routeTypeClosure = {
            content.getRouteType()
        }
        outputableClosure = {
            content
        }
    }

    /// Create view using preserved type information (type-erased for collection storage)
    func createView() -> AnyView {
        return createViewClosure()
    }

    /// Get route type
    func getRouteType() -> Any {
        return routeTypeClosure()
    }

    /// Get type-safe outputable
    func getOutputable() -> any TypeSafeNavigationOutputable {
        return outputableClosure()
    }
}

// MARK: - NavigationContent Class with Associated Types

public class NavigationContent<T: NavigationCoordinatable, U: RouteType, Input, Output: ViewPresentable> {
    let type: U
    let closure: (T) -> ((Input) -> Output)

    private var output: Output?
    private let outputLock = NSLock()

    init(
        type: U,
        closure: @escaping ((T) -> ((Input) -> Output))
    ) {
        self.type = type
        self.closure = closure
    }

    /// Create the presentable Output for this coordinator with the given input.
    func createPresentable(for coordinator: T, input: Input) -> Output {
        outputLock.lock()
        defer { outputLock.unlock() }
        let closureOutput = closure(coordinator)(input)
        output = closureOutput
        return closureOutput
    }

    /// Create type-safe wrapper preserving specific types
    func createWrapper(for coordinator: T, input: Input) -> TypeSafeNavigationWrapper<Output.PresentedView> {
        return TypeSafeNavigationWrapper(coordinator: coordinator, input: input, content: self)
    }

    /// Get the route type for this navigation content.
    func getRouteType() -> U {
        return type
    }
}

// MARK: - NavigationOutputable removed - using only TypeSafeNavigationOutputable

// MARK: - TypeSafeNavigationOutputable Implementation

extension NavigationContent: TypeSafeNavigationOutputable {
    public typealias PresentableType = Output

    public func using(coordinator: Any, input: Any) -> Output {
        if Input.self == Void.self {
            return closure(coordinator as! T)(() as! Input)
        } else {
            return closure(coordinator as! T)(input as! Input)
        }
    }
}

@propertyWrapper public struct NavigationRoute<T: NavigationCoordinatable, U: RouteType, Input, Output: ViewPresentable> {
    public let wrappedValue: Transition<T, U, Input, Output>
    private let routeType: U
    private let closure: (T) -> (Input) -> Output

    // MARK: - Presentation Routes

    // 1. Presentation - Coordinatable without input (Void)
    public init(
        wrappedValue: @escaping (T) -> () -> Output,
        _ presentation: PresentationType
    ) where U == Presentation, Input == Void, Output: Coordinatable {
        let closureValue: (T) -> (Input) -> Output = { coordinator in { (_: Input) in wrappedValue(coordinator)() } }
        closure = closureValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: closureValue)
    }

    // 2. Presentation - Coordinatable with input
    public init(
        wrappedValue: @escaping (T) -> (Input) -> Output,
        _ presentation: PresentationType
    ) where U == Presentation, Output: Coordinatable {
        closure = wrappedValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: wrappedValue)
    }

    // 3. Presentation - View as AnyView without input (Void)
    public init<ViewOutput: View>(
        wrappedValue: @escaping (T) -> () -> ViewOutput,
        _ presentation: PresentationType
    ) where U == Presentation, Input == Void, Output == AnyView {
        let closureValue: (T) -> (Input) -> Output = { coordinator in { (_: Input) in AnyView(wrappedValue(coordinator)()) } }
        closure = closureValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: closureValue)
    }

    // 4. Presentation - View as AnyView with input
    public init<ViewOutput: View>(
        wrappedValue: @escaping (T) -> (Input) -> ViewOutput,
        _ presentation: PresentationType
    ) where U == Presentation, Output == AnyView {
        let closureValue: (T) -> (Input) -> Output = { coordinator in { input in AnyView(wrappedValue(coordinator)(input)) } }
        closure = closureValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: closureValue)
    }

    // MARK: - RootSwitch Routes

    // 5. RootSwitch - Coordinatable without input (Void)
    public init(
        _ closureValue: @escaping (T) -> () -> Output
    ) where U == RootSwitch, Input == Void, Output: Coordinatable {
        let adaptedClosure: (T) -> (Input) -> Output = { coordinator in { (_: Input) in closureValue(coordinator)() } }
        closure = adaptedClosure
        routeType = RootSwitch()
        wrappedValue = Transition(type: routeType, closure: adaptedClosure)
    }

    // 6. RootSwitch - Coordinatable with input
    public init(
        _ closureValue: @escaping (T) -> (Input) -> Output
    ) where U == RootSwitch, Output: Coordinatable {
        closure = closureValue
        routeType = RootSwitch()
        wrappedValue = Transition(type: routeType, closure: closureValue)
    }

    // 7. RootSwitch - View as AnyView without input (Void)
    public init<ViewOutput: View>(
        _ closureValue: @escaping (T) -> () -> ViewOutput
    ) where U == RootSwitch, Input == Void, Output == AnyView {
        let adaptedClosure: (T) -> (Input) -> Output = { coordinator in { (_: Input) in AnyView(closureValue(coordinator)()) } }
        closure = adaptedClosure
        routeType = RootSwitch()
        wrappedValue = Transition(type: routeType, closure: adaptedClosure)
    }

    // 8. RootSwitch - View as AnyView with input
    public init<ViewOutput: View>(
        _ closureValue: @escaping (T) -> (Input) -> ViewOutput
    ) where U == RootSwitch, Output == AnyView {
        let adaptedClosure: (T) -> (Input) -> Output = { coordinator in { input in AnyView(closureValue(coordinator)(input)) } }
        closure = adaptedClosure
        routeType = RootSwitch()
        wrappedValue = Transition(type: routeType, closure: adaptedClosure)
    }

    public var projectedValue: NavigationContent<T, U, Input, Output> {
        NavigationContent(
            type: routeType,
            closure: closure
        )
    }
}

// MARK: - Legacy Transition Support (for backward compatibility)

public struct Transition<T: NavigationCoordinatable, U: RouteType, Input, Output: ViewPresentable>: TypeSafeNavigationOutputable {
    public typealias PresentableType = Output

    let type: U
    let closure: (T) -> ((Input) -> Output)

    // Type-safe method for TypeSafeNavigationOutputable
    public func using(coordinator: Any, input: Any) -> Output {
        if Input.self == Void.self {
            return closure(coordinator as! T)(() as! Input)
        } else {
            return closure(coordinator as! T)(input as! Input)
        }
    }
}

// MARK: - Root Transition Provider Protocol

/// Protocol for accessing the transition from Root property wrappers
public protocol RootTransitionProvider {
    func getTransition() -> any TypeSafeNavigationOutputable
}

// MARK: - Root Property Wrapper (for Root Routes)

@propertyWrapper public struct Root<T: NavigationCoordinatable, Input, Output: ViewPresentable>: RootTransitionProvider {
    private let closure: (T) -> (Input) -> Output
    private let transition: Transition<T, RootSwitch, Input, Output>

    public var wrappedValue: Transition<T, RootSwitch, Input, Output> {
        return transition
    }

    // MARK: - Safe Direct Initializers (use @Root(closure) syntax)

    // Root - Coordinatable without input (Void)
    public init(
        _ closureValue: @escaping (T) -> () -> Output
    ) where Input == Void, Output: Coordinatable {
        let adaptedClosure: (T) -> (Input) -> Output = { coordinator in { (_: Input) in closureValue(coordinator)() } }
        closure = adaptedClosure
        transition = Transition(type: RootSwitch(), closure: adaptedClosure)
    }

    // Root - Coordinatable with input
    public init(
        _ closureValue: @escaping (T) -> (Input) -> Output
    ) where Output: Coordinatable {
        closure = closureValue
        transition = Transition(type: RootSwitch(), closure: closureValue)
    }

    // Root - View as AnyView without input (Void)
    public init<ViewOutput: View>(
        _ closureValue: @escaping (T) -> () -> ViewOutput
    ) where Input == Void, Output == AnyView {
        let adaptedClosure: (T) -> (Input) -> Output = { coordinator in { (_: Input) in AnyView(closureValue(coordinator)()) } }
        closure = adaptedClosure
        transition = Transition(type: RootSwitch(), closure: adaptedClosure)
    }

    // Root - View as AnyView with input
    public init<ViewOutput: View>(
        _ closureValue: @escaping (T) -> (Input) -> ViewOutput
    ) where Output == AnyView {
        let adaptedClosure: (T) -> (Input) -> Output = { coordinator in { input in AnyView(closureValue(coordinator)(input)) } }
        closure = adaptedClosure
        transition = Transition(type: RootSwitch(), closure: adaptedClosure)
    }

    public var projectedValue: NavigationContent<T, RootSwitch, Input, Output> {
        NavigationContent(
            type: RootSwitch(),
            closure: closure
        )
    }

    // MARK: - RootTransitionProvider Conformance

    public func getTransition() -> any TypeSafeNavigationOutputable {
        return transition
    }
}

// MARK: - Type-Safe Route Collection Support

public protocol NavigationRouteCollectable {
    associatedtype CoordinatorType: NavigationCoordinatable
    func createWrapper(for coordinator: CoordinatorType, input: Any) -> AnyNavigationWrapper
}

extension NavigationContent: NavigationRouteCollectable {
    public typealias CoordinatorType = T

    public func createWrapper(for coordinator: T, input: Any) -> AnyNavigationWrapper {
        if Input.self == Void.self {
            return createAnyWrapper(for: coordinator, input: () as! Input)
        } else {
            return createAnyWrapper(for: coordinator, input: input as! Input)
        }
    }

    /// Create type-erased wrapper for collection storage
    private func createAnyWrapper(for coordinator: T, input: Input) -> AnyNavigationWrapper {
        return AnyNavigationWrapper(coordinator: coordinator, input: input, content: self)
    }
}

// MARK: - ChildCoordinatable Extensions

public extension NavigationRoute where Output: ChildCoordinatable {
    // Presentation - ChildCoordinatable without input (Void)
    init(
        wrappedValue: @escaping (T) -> () -> Output,
        _ presentation: PresentationType
    ) where U == Presentation, Input == Void {
        let closureValue: (T) -> (Input) -> Output = { coordinator in { (_: Input) in wrappedValue(coordinator)() } }
        closure = closureValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: closureValue)
    }

    // Presentation - ChildCoordinatable with input
    init(
        wrappedValue: @escaping (T) -> (Input) -> Output,
        _ presentation: PresentationType
    ) where U == Presentation {
        closure = wrappedValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: wrappedValue)
    }
}

public extension Root where Output: ChildCoordinatable {
    // Root - ChildCoordinatable without input (Void)
    init(
        _ closureValue: @escaping (T) -> () -> Output
    ) where Input == Void {
        let adaptedClosure: (T) -> (Input) -> Output = { coordinator in { (_: Input) in closureValue(coordinator)() } }
        closure = adaptedClosure
        transition = Transition(type: RootSwitch(), closure: adaptedClosure)
    }

    // Root - ChildCoordinatable with input
    init(
        _ closureValue: @escaping (T) -> (Input) -> Output
    ) {
        closure = closureValue
        transition = Transition(type: RootSwitch(), closure: closureValue)
    }
}

// MARK: - ChildCoordinatable Extensions for NavigationRoute

/// Extensions to allow child coordinators to use @NavigationRoute with their parent's type
public extension NavigationRoute where T: NavigationCoordinatable {
    // MARK: - Child Coordinator Presentation Routes

    /// Presentation route for child coordinators - View without input (Void)
    /// Usage: @NavigationRoute<ParentType, Presentation, Void, AnyView>(.push) var route = makeView
    init<ViewOutput: View>(
        wrappedValue: @escaping () -> ViewOutput,
        _ presentation: PresentationType
    ) where U == Presentation, Input == Void, Output == AnyView {
        let closureValue: (T) -> (Input) -> Output = { _ in { (_: Input) in AnyView(wrappedValue()) } }
        closure = closureValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: closureValue)
    }

    /// Presentation route for child coordinators - View with input
    /// Usage: @NavigationRoute<ParentType, Presentation, InputType, AnyView>(.push) var route = makeView
    init<ViewOutput: View>(
        wrappedValue: @escaping (Input) -> ViewOutput,
        _ presentation: PresentationType
    ) where U == Presentation, Output == AnyView {
        let closureValue: (T) -> (Input) -> Output = { _ in { input in AnyView(wrappedValue(input)) } }
        closure = closureValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: closureValue)
    }

    /// Presentation route for child coordinators - Coordinatable without input (Void)
    /// Usage: @NavigationRoute<ParentType, Presentation, Void, ChildCoordinator>(.push) var route = makeCoordinator
    init(
        wrappedValue: @escaping () -> Output,
        _ presentation: PresentationType
    ) where U == Presentation, Input == Void, Output: Coordinatable {
        let closureValue: (T) -> (Input) -> Output = { _ in { (_: Input) in wrappedValue() } }
        closure = closureValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: closureValue)
    }

    /// Presentation route for child coordinators - Coordinatable with input
    /// Usage: @NavigationRoute<ParentType, Presentation, InputType, ChildCoordinator>(.push) var route = makeCoordinator
    init(
        wrappedValue: @escaping (Input) -> Output,
        _ presentation: PresentationType
    ) where U == Presentation, Output: Coordinatable {
        let closureValue: (T) -> (Input) -> Output = { _ in wrappedValue }
        closure = closureValue
        routeType = Presentation(type: presentation)
        self.wrappedValue = Transition(type: routeType, closure: closureValue)
    }
}

/// Extension to add routing capabilities to child coordinators using NavigationRoute
public extension ChildCoordinatable {
    /// Routes using a NavigationRoute transition from a child coordinator
    /// This allows child coordinators to use @NavigationRoute with their parent's type
    @discardableResult
    func route<U: RouteType, Input, Output: ViewPresentable>(
        to route: Transition<Parent, U, Input, Output>,
        _ input: Input
    ) -> Self {
        guard let parent = parent else {
            print("Warning: Cannot route - parent coordinator is nil")
            return self
        }

        // Use the transition to create the output
        let output = route.using(coordinator: parent, input: input)

        // Create NavigationStackItem and add to parent's stack
        let keyPath = ObjectIdentifier(type(of: route.closure)).hashValue

        if let presentation = route.type as? Presentation {
            let stackItem = NavigationStackItem(
                presentationType: presentation.type,
                presentable: output,
                keyPath: keyPath,
                input: input
            )

            // Set parent relationship for coordinators
            if let coordinator = output as? any Coordinatable {
                coordinator.parent = parent
            }

            // Add to parent's stack
            parent.stack.value.append(stackItem)
        }

        return self
    }

    /// Routes using a NavigationRoute transition without input
    @discardableResult
    func route<U: RouteType, Output: ViewPresentable>(
        to route: Transition<Parent, U, Void, Output>
    ) -> Self {
        return self.route(to: route, ())
    }

    /// Routes using a NavigationRoute transition and returns the coordinator
    @discardableResult
    func route<U: RouteType, Input, Output: Coordinatable>(
        to route: Transition<Parent, U, Input, Output>,
        _ input: Input
    ) -> Output {
        guard let parent = parent else {
            print("Warning: Cannot route - parent coordinator is nil")
            return route.using(coordinator: parent!, input: input) // This will crash, but it's better than returning nil
        }

        // Use the transition to create the output
        let output = route.using(coordinator: parent, input: input)

        // Create NavigationStackItem and add to parent's stack
        let keyPath = ObjectIdentifier(type(of: route.closure)).hashValue

        if let presentation = route.type as? Presentation {
            let stackItem = NavigationStackItem(
                presentationType: presentation.type,
                presentable: output,
                keyPath: keyPath,
                input: input
            )

            // Set parent relationship
            output.parent = parent

            // Add to parent's stack
            parent.stack.value.append(stackItem)
        }

        return output
    }

    /// Routes using a NavigationRoute transition without input and returns the coordinator
    @discardableResult
    func route<U: RouteType, Output: Coordinatable>(
        to route: Transition<Parent, U, Void, Output>
    ) -> Output {
        return self.route(to: route, ())
    }
}
