import Foundation
import SwiftUI

/// A property wrapper that enables child coordinators to route through their parent's navigation stack.
///
/// ChildRoute provides a way for child coordinators to define routes that will be executed
/// on their parent's navigation stack, similar to how @NavigationRoute works for parent coordinators.
///
/// ## Usage Example
/// ```swift
/// final class ChildCoordinator: ChildCoordinatable {
///     weak var parent: ParentCoordinator?
///
///     @ChildRoute(.push) var childDetailView = makeChildDetailView
///     @ChildRoute(.modal) var childSettingsView = makeChildSettingsView
///
///     func makeChildDetailView() -> some View {
///         DetailView()
///     }
///
///     func makeChildSettingsView() -> some View {
///         SettingsView()
///     }
///
///     func showDetail() {
///         route(childDetailView)
///     }
///
///     func showSettings() {
///         route(childSettingsView)
///     }
/// }
/// ```
@propertyWrapper public struct ChildRoute<C: ChildCoordinatable, Input, Output: ViewPresentable> {
    private let presentationType: PresentationType
    private let closure: (C) -> (Input) -> Output

    public var wrappedValue: ChildRouteAction<C, Input, Output> {
        return ChildRouteAction(presentationType, closure: closure)
    }

    // MARK: - Initializers for Views

    /// Creates a child route with the specified presentation type and closure for Views without input (Void)
    public init<ViewOutput: View>(
        wrappedValue: @escaping (C) -> () -> ViewOutput,
        _ presentation: PresentationType
    ) where Input == Void, Output == AnyView {
        let closureValue: (C) -> (Input) -> Output = { coordinator in { (_: Input) in AnyView(wrappedValue(coordinator)()) } }
        presentationType = presentation
        closure = closureValue
    }

    /// Creates a child route with the specified presentation type and closure for Views with input
    public init<ViewOutput: View>(
        wrappedValue: @escaping (C) -> (Input) -> ViewOutput,
        _ presentation: PresentationType
    ) where Output == AnyView {
        let closureValue: (C) -> (Input) -> Output = { coordinator in { input in AnyView(wrappedValue(coordinator)(input)) } }
        presentationType = presentation
        closure = closureValue
    }

    // MARK: - Initializers for Coordinators

    /// Creates a child route with the specified presentation type and closure for Coordinators without input (Void)
    public init(
        wrappedValue: @escaping (C) -> () -> Output,
        _ presentation: PresentationType
    ) where Input == Void, Output: Coordinatable {
        let closureValue: (C) -> (Input) -> Output = { coordinator in { (_: Input) in wrappedValue(coordinator)() } }
        presentationType = presentation
        closure = closureValue
    }

    /// Creates a child route with the specified presentation type and closure for Coordinators with input
    public init(
        wrappedValue: @escaping (C) -> (Input) -> Output,
        _ presentation: PresentationType
    ) where Output: Coordinatable {
        presentationType = presentation
        closure = wrappedValue
    }

    public var projectedValue: ChildRouteContent<C, Input, Output> {
        return ChildRouteContent(presentationType: presentationType, closure: closure)
    }
}

/// Content type for child routes (similar to NavigationContent)
public struct ChildRouteContent<C: ChildCoordinatable, Input, Output: ViewPresentable> {
    let presentationType: PresentationType
    let closure: (C) -> (Input) -> Output

    /// Create the presentable Output for this coordinator with the given input.
    func createPresentable(for coordinator: C, input: Input) -> Output {
        return closure(coordinator)(input)
    }
}

/// Protocol for type-erased access to ChildRouteAction
public protocol ChildRouteActionProtocol {
    /// Creates a view output for the given coordinator
    func createViewOutput<C: ChildCoordinatable>(for coordinator: C) -> AnyView
}

/// Action type that represents a route that can be executed by a child coordinator
public struct ChildRouteAction<C: ChildCoordinatable, Input, Output: ViewPresentable>: ChildRouteActionProtocol {
    public let presentationType: PresentationType
    public let closure: (C) -> (Input) -> Output

    public init(_ presentationType: PresentationType, closure: @escaping (C) -> (Input) -> Output) {
        self.presentationType = presentationType
        self.closure = closure
    }

    /// Creates the output for this route using the coordinator and input
    public func createOutput(for coordinator: C, input: Input) -> Output {
        return closure(coordinator)(input)
    }

    /// Creates a view output for the given coordinator (for protocol conformance)
    public func createViewOutput<Coordinator: ChildCoordinatable>(for coordinator: Coordinator) -> AnyView {
        guard let typedCoordinator = coordinator as? C else {
            fatalError("Coordinator type mismatch")
        }

        // For root views, we use Void input
        let output = closure(typedCoordinator)(() as! Input)

        if let view = output as? any View {
            return AnyView(view)
        } else if let anyView = output as? AnyView {
            return anyView
        } else {
            fatalError("ChildRoute root must produce a View or AnyView")
        }
    }
}

/// Extension to add routing capabilities to child coordinators
public extension ChildCoordinatable {
    // MARK: - Consistent Routing Helpers (mirroring NavigationRoute)

    /// Routes using a `ChildRouteAction` without input and returns the child coordinator (`self`) for chaining.
    @discardableResult
    func route<Output: ViewPresentable>(
        _ childRoute: ChildRouteAction<Self, Void, Output>
    ) -> Self {
        guard let parent = parent else {
            print("Warning: Cannot route - parent coordinator is nil")
            return self
        }

        // Produce the output from the supplied closure
        let output = childRoute.createOutput(for: self, input: ())

        // Generate a unique key for stack identification (similar to NavigationRoute)
        let keyPath = ObjectIdentifier(type(of: childRoute.closure)).hashValue

        // If the output is a coordinator, set its parent relationship
        if let coordinatorOutput = output as? any Coordinatable {
            coordinatorOutput.parent = parent
        }

        // Create stack item and append to parent's stack
        let stackItem = NavigationStackItem(
            presentationType: childRoute.presentationType,
            presentable: output,
            keyPath: keyPath,
            input: nil
        )

        parent.stack.value.append(stackItem)

        return self
    }

    /// Routes using a `ChildRouteAction` with input and returns the child coordinator (`self`) for chaining.
    @discardableResult
    func route<Input, Output: ViewPresentable>(
        _ childRoute: ChildRouteAction<Self, Input, Output>,
        _ input: Input
    ) -> Self {
        guard let parent = parent else {
            print("Warning: Cannot route - parent coordinator is nil")
            return self
        }

        // Produce the output from the supplied closure
        let output = childRoute.createOutput(for: self, input: input)

        // Generate a unique key for stack identification (similar to NavigationRoute)
        let keyPath = ObjectIdentifier(type(of: childRoute.closure)).hashValue

        // If the output is a coordinator, set its parent relationship
        if let coordinatorOutput = output as? any Coordinatable {
            coordinatorOutput.parent = parent
        }

        // Create stack item and append to parent's stack
        let stackItem = NavigationStackItem(
            presentationType: childRoute.presentationType,
            presentable: output,
            keyPath: keyPath,
            input: input
        )

        parent.stack.value.append(stackItem)

        return self
    }

    /// Routes using a `ChildRouteAction` without input and returns the created coordinator.
    /// Only available when the output itself is a `Coordinatable`.
    @discardableResult
    func route<Output: Coordinatable>(
        _ childRoute: ChildRouteAction<Self, Void, Output>
    ) -> Output {
        guard let parent = parent else {
            print("Warning: Cannot route - parent coordinator is nil")
            return childRoute.createOutput(for: self, input: ())
        }

        let output = childRoute.createOutput(for: self, input: ())
        output.parent = parent

        let keyPath = ObjectIdentifier(type(of: childRoute.closure)).hashValue

        let stackItem = NavigationStackItem(
            presentationType: childRoute.presentationType,
            presentable: output,
            keyPath: keyPath,
            input: nil
        )

        parent.stack.value.append(stackItem)

        return output
    }

    /// Routes using a `ChildRouteAction` with input and returns the created coordinator.
    /// Only available when the output itself is a `Coordinatable`.
    @discardableResult
    func route<Input, Output: Coordinatable>(
        _ childRoute: ChildRouteAction<Self, Input, Output>,
        _ input: Input
    ) -> Output {
        guard let parent = parent else {
            print("Warning: Cannot route - parent coordinator is nil")
            return childRoute.createOutput(for: self, input: input)
        }

        let output = childRoute.createOutput(for: self, input: input)
        output.parent = parent

        let keyPath = ObjectIdentifier(type(of: childRoute.closure)).hashValue

        let stackItem = NavigationStackItem(
            presentationType: childRoute.presentationType,
            presentable: output,
            keyPath: keyPath,
            input: input
        )

        parent.stack.value.append(stackItem)

        return output
    }
}
