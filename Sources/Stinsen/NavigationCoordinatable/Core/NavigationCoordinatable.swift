import Combine
import Foundation
import SwiftUI

/// A protocol that defines a coordinator capable of managing navigation within a SwiftUI NavigationStack.
///
/// NavigationCoordinatable provides a comprehensive API for managing navigation state, including:
/// - Push navigation using SwiftUI's NavigationStack
/// - Modal presentations using .sheet()
/// - Full-screen presentations using .fullScreenCover() (iOS only)
/// - Stack manipulation (pop, focus, root switching)
/// - Dismissal action handling
///
/// ## Usage Example
/// ```swift
/// final class HomeCoordinator: NavigationCoordinatable {
///     var stack = NavigationStack(initial: \.home)
///
///     @Route(.push) var home = makeHome
///     @Route(.modal) var settings = makeSettings
///
///     func makeHome() -> HomeView {
///         HomeView()
///     }
///
///     func makeSettings() -> SettingsCoordinator {
///         SettingsCoordinator()
///     }
/// }
/// ```
public protocol NavigationCoordinatable: Coordinatable {
    typealias Route = NavigationRoute
    typealias Router = NavigationRouter<Self>
    associatedtype CustomizeViewType: View
    associatedtype RouterStoreType

    var embeddedInStack: Bool { get }
    var routerStorable: RouterStoreType { get }
    var stack: NavigationStack<Self> { get set }

    /// Customizes the appearance of all views and child coordinators in the navigation hierarchy.
    ///
    /// This function allows you to apply global styling, inject environment objects, or modify
    /// the view hierarchy for all screens managed by this coordinator.
    ///
    /// - Parameter view: The input view to be customized
    /// - Returns: The modified view with applied customizations
    ///
    /// ## Example
    /// ```swift
    /// func customize(_ view: AnyView) -> some View {
    ///     view
    ///         .tint(.blue)
    ///         .environmentObject(themeManager)
    ///         .navigationBarTitleDisplayMode(.inline)
    /// }
    /// ```
    func customize(_ view: AnyView) -> CustomizeViewType

    /// Dismisses the current coordinator by notifying its parent coordinator.
    ///
    /// This function should be called when the coordinator needs to be removed from the navigation
    /// hierarchy. It will trigger the parent coordinator to handle the dismissal appropriately.
    ///
    /// - Parameter action: Optional closure to execute after dismissal completes
    ///
    /// ## Usage
    /// ```swift
    /// // Simple dismissal
    /// coordinator.dismissCoordinator()
    ///
    /// // Dismissal with completion action
    /// coordinator.dismissCoordinator {
    ///     print("Coordinator dismissed")
    /// }
    /// ```
    func dismissCoordinator(_ action: (() -> Void)?)

    /// Removes all items from the navigation stack, returning to the root view.
    ///
    /// This is equivalent to pressing the back button multiple times until reaching the initial screen.
    /// All intermediate views will be removed from the stack and their dismissal actions will be called.
    ///
    /// - Parameter action: Optional closure to execute after popping to root completes
    /// - Returns: Self for method chaining
    ///
    /// ## Example
    /// ```swift
    /// coordinator
    ///     .popToRoot {
    ///         print("Returned to root")
    ///     }
    ///     .route(to: \.newScreen)
    /// ```
    @discardableResult func popToRoot(_ action: (() -> Void)?) -> Self

    /// Navigates to a view-based route with input parameters.
    ///
    /// Appends a new view to the navigation stack using the specified route and input parameters.
    /// The presentation type (push, modal, fullScreen) is determined by the route's configuration.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the route transition that creates the target view
    ///   - input: Parameters passed to the view creation closure
    /// - Returns: Self for method chaining
    ///
    /// ## Example
    /// ```swift
    /// coordinator.route(to: \.userProfile, user)
    /// ```
    @discardableResult
    func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>, _ input: Input
    ) -> Self

    /// Navigates to a coordinator-based route with input parameters.
    ///
    /// Appends a new coordinator to the navigation stack using the specified route and input parameters.
    /// The created coordinator becomes a child of the current coordinator and can manage its own navigation.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the route transition that creates the target coordinator
    ///   - input: Parameters passed to the coordinator creation closure
    /// - Returns: The newly created coordinator instance
    ///
    /// ## Example
    /// ```swift
    /// let settingsCoordinator = coordinator.route(to: \.settings, settingsConfig)
    /// settingsCoordinator.route(to: \.profile)
    /// ```
    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output

    /// Navigates to a coordinator-based route without input parameters.
    ///
    /// Appends a new coordinator to the navigation stack using the specified route.
    /// This is a convenience method for routes that don't require input parameters.
    ///
    /// - Parameter route: KeyPath to the route transition that creates the target coordinator
    /// - Returns: The newly created coordinator instance
    ///
    /// ## Example
    /// ```swift
    /// let profileCoordinator = coordinator.route(to: \.profile)
    /// ```
    @discardableResult
    func route<Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Output

    /// Navigates to a view-based route without input parameters.
    ///
    /// Appends a new view to the navigation stack using the specified route.
    /// This is a convenience method for routes that don't require input parameters.
    ///
    /// - Parameter route: KeyPath to the route transition that creates the target view
    /// - Returns: Self for method chaining
    ///
    /// ## Example
    /// ```swift
    /// coordinator.route(to: \.settings)
    /// ```
    @discardableResult
    func route<Output: View>(to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>)
        -> Self

    /// Searches the navigation stack for a coordinator route and focuses on it.
    ///
    /// Removes all navigation items after the first occurrence of the specified route,
    /// effectively "focusing" on that coordinator. This is useful for deep-linking or
    /// returning to a specific point in the navigation hierarchy.
    ///
    /// - Parameter route: The coordinator route to focus on
    /// - Returns: The focused coordinator instance
    /// - Throws: `FocusError.routeNotFound` if the route is not found in the stack
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let profileCoordinator = try coordinator.focusFirst(\.profile)
    ///     profileCoordinator.route(to: \.editProfile)
    /// } catch {
    ///     print("Profile route not found in stack")
    /// }
    /// ```
    @discardableResult
    func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) throws -> Output

    /// Searches the navigation stack for a view route and focuses on it.
    ///
    /// Removes all navigation items after the first occurrence of the specified route,
    /// effectively "focusing" on that view.
    ///
    /// - Parameter route: The view route to focus on
    /// - Returns: Self for method chaining
    /// - Throws: `FocusError.routeNotFound` if the route is not found in the stack
    ///
    /// ## Example
    /// ```swift
    /// try coordinator.focusFirst(\.homeView)
    /// ```
    @discardableResult
    func focusFirst<Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) throws -> Self

    /// Searches the navigation stack for a coordinator route with specific input and focuses on it.
    ///
    /// Uses a custom comparator function to match routes with specific input parameters.
    /// This allows for precise focusing when multiple instances of the same route exist with different inputs.
    ///
    /// - Parameters:
    ///   - route: The coordinator route to focus on
    ///   - input: The input parameters to match
    ///   - comparator: Function to compare input parameters for equality
    /// - Returns: The focused coordinator instance
    /// - Throws: `FocusError.routeNotFound` if no matching route is found
    ///
    /// ## Example
    /// ```swift
    /// let userCoordinator = try coordinator.focusFirst(
    ///     \.userProfile,
    ///     targetUser,
    ///     comparator: { $0.id == $1.id }
    /// )
    /// ```
    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Output

    /// Searches the navigation stack for a view route with specific input and focuses on it.
    ///
    /// Uses a custom comparator function to match routes with specific input parameters.
    ///
    /// - Parameters:
    ///   - route: The view route to focus on
    ///   - input: The input parameters to match
    ///   - comparator: Function to compare input parameters for equality
    /// - Returns: Self for method chaining
    /// - Throws: `FocusError.routeNotFound` if no matching route is found
    @discardableResult func focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Self

    /// Searches the navigation stack for a coordinator route with Equatable input and focuses on it.
    ///
    /// Convenience method that uses the `==` operator for input comparison when the input type is Equatable.
    ///
    /// - Parameters:
    ///   - route: The coordinator route to focus on
    ///   - input: The Equatable input parameters to match
    /// - Returns: The focused coordinator instance
    /// - Throws: `FocusError.routeNotFound` if no matching route is found
    ///
    /// ## Example
    /// ```swift
    /// let userCoordinator = try coordinator.focusFirst(\.userProfile, userId)
    /// ```
    @discardableResult func focusFirst<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Output

    /// Searches the navigation stack for a view route with Equatable input and focuses on it.
    ///
    /// Convenience method that uses the `==` operator for input comparison when the input type is Equatable.
    ///
    /// - Parameters:
    ///   - route: The view route to focus on
    ///   - input: The Equatable input parameters to match
    /// - Returns: Self for method chaining
    /// - Throws: `FocusError.routeNotFound` if no matching route is found
    @discardableResult func focusFirst<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Self

    /// Searches the navigation stack for a coordinator route and focuses on it (input-agnostic).
    ///
    /// Focuses on the first occurrence of the specified route regardless of input parameters.
    /// Useful when you want to focus on a route type without caring about specific inputs.
    ///
    /// - Parameter route: The coordinator route to focus on
    /// - Returns: The focused coordinator instance
    /// - Throws: `FocusError.routeNotFound` if the route is not found in the stack
    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Output

    /// Searches the navigation stack for a view route and focuses on it (input-agnostic).
    ///
    /// Focuses on the first occurrence of the specified route regardless of input parameters.
    ///
    /// - Parameter route: The view route to focus on
    /// - Returns: Self for method chaining
    /// - Throws: `FocusError.routeNotFound` if the route is not found in the stack
    @discardableResult
    func focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Self

    // MARK: - Root Management Functions

    /// Switches to a coordinator-based root route without input parameters.
    ///
    /// Replaces the current root coordinator with a new one. This is typically used for
    /// major navigation changes like switching between authenticated and unauthenticated states.
    ///
    /// - Parameter route: KeyPath to the root transition that creates the target coordinator
    /// - Returns: The newly created root coordinator instance
    ///
    /// ## Example
    /// ```swift
    /// let authCoordinator = coordinator.root(\.authenticated)
    /// ```
    @discardableResult
    func root<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output

    /// Switches to a view-based root route without input parameters.
    ///
    /// Replaces the current root view with a new one.
    ///
    /// - Parameter route: KeyPath to the root transition that creates the target view
    /// - Returns: Self for method chaining
    @discardableResult func root<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Self

    /// Switches to a coordinator-based root route with input parameters.
    ///
    /// Replaces the current root coordinator with a new one, passing input parameters.
    ///
    /// - Parameter route: KeyPath to the root transition that creates the target coordinator
    /// - Returns: The newly created root coordinator instance
    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output

    /// Switches to a view-based root route with input parameters.
    ///
    /// Replaces the current root view with a new one, passing input parameters.
    ///
    /// - Parameter route: KeyPath to the root transition that creates the target view
    /// - Returns: Self for method chaining
    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Self

    /// Switches to a coordinator-based root route with input parameters and custom comparator.
    ///
    /// Replaces the current root coordinator, using a custom comparator for input matching.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition
    ///   - input: Input parameters for the new root
    ///   - comparator: Function to compare input parameters
    /// - Returns: The newly created root coordinator instance
    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output

    /// Switches to a view-based root route with input parameters and custom comparator.
    ///
    /// Replaces the current root view, using a custom comparator for input matching.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition
    ///   - input: Input parameters for the new root
    ///   - comparator: Function to compare input parameters
    /// - Returns: Self for method chaining
    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Self

    /// Switches to a coordinator-based root route with Equatable input parameters.
    ///
    /// Convenience method that uses the `==` operator for input comparison when the input type is Equatable.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition
    ///   - input: Equatable input parameters for the new root
    /// - Returns: The newly created root coordinator instance
    @discardableResult func root<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output

    /// Switches to a view-based root route with Equatable input parameters.
    ///
    /// Convenience method that uses the `==` operator for input comparison when the input type is Equatable.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition
    ///   - input: Equatable input parameters for the new root
    /// - Returns: Self for method chaining
    @discardableResult func root<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Self

    // MARK: - Root State Checking Functions

    /// Checks if the specified coordinator route is currently the root.
    ///
    /// Determines whether the given route without input parameters is currently set as the root coordinator.
    ///
    /// - Parameter route: KeyPath to the root transition to check
    /// - Returns: `true` if the route is currently the root, `false` otherwise
    ///
    /// ## Example
    /// ```swift
    /// if coordinator.isRoot(\.authenticated) {
    ///     print("User is authenticated")
    /// }
    /// ```
    func isRoot<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Bool

    /// Checks if the specified view route is currently the root.
    ///
    /// Determines whether the given view route without input parameters is currently set as the root.
    ///
    /// - Parameter route: KeyPath to the root transition to check
    /// - Returns: `true` if the route is currently the root, `false` otherwise
    func isRoot<Output: View>(_ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>)
        -> Bool

    /// Checks if the specified coordinator route is currently the root (input-agnostic).
    ///
    /// Determines whether the given route is currently set as the root, regardless of input parameters.
    ///
    /// - Parameter route: KeyPath to the root transition to check
    /// - Returns: `true` if the route is currently the root, `false` otherwise
    func isRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool

    /// Checks if the specified view route is currently the root (input-agnostic).
    ///
    /// Determines whether the given view route is currently set as the root, regardless of input parameters.
    ///
    /// - Parameter route: KeyPath to the root transition to check
    /// - Returns: `true` if the route is currently the root, `false` otherwise
    func isRoot<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool

    /// Checks if the specified coordinator route with Equatable input is currently the root.
    ///
    /// Determines whether the given route with specific Equatable input parameters is currently set as the root.
    /// Uses the `==` operator for input comparison.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition to check
    ///   - input: Equatable input parameters to match
    /// - Returns: `true` if the route with matching input is currently the root, `false` otherwise
    func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool

    /// Checks if the specified view route with Equatable input is currently the root.
    ///
    /// Determines whether the given view route with specific Equatable input parameters is currently set as the root.
    /// Uses the `==` operator for input comparison.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition to check
    ///   - input: Equatable input parameters to match
    /// - Returns: `true` if the route with matching input is currently the root, `false` otherwise
    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool

    /// Checks if the specified coordinator route with custom comparator is currently the root.
    ///
    /// Determines whether the given route with specific input parameters is currently set as the root.
    /// Uses a custom comparator function for input comparison.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition to check
    ///   - input: Input parameters to match
    ///   - comparator: Function to compare input parameters for equality
    /// - Returns: `true` if the route with matching input is currently the root, `false` otherwise
    func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool

    /// Checks if the specified view route with custom comparator is currently the root.
    ///
    /// Determines whether the given view route with specific input parameters is currently set as the root.
    /// Uses a custom comparator function for input comparison.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition to check
    ///   - input: Input parameters to match
    ///   - comparator: Function to compare input parameters for equality
    /// - Returns: `true` if the route with matching input is currently the root, `false` otherwise
    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool

    // MARK: - Root Existence Checking Functions

    /// Returns the coordinator instance if the specified route is currently the root.
    ///
    /// Checks if the given coordinator route (input-agnostic) is currently set as the root and returns
    /// the coordinator instance if found, or `nil` if not.
    ///
    /// - Parameter route: KeyPath to the root transition to check
    /// - Returns: The coordinator instance if it's the current root, `nil` otherwise
    ///
    /// ## Example
    /// ```swift
    /// if let authCoordinator = coordinator.hasRoot(\.authenticated) {
    ///     authCoordinator.route(to: \.dashboard)
    /// }
    /// ```
    @discardableResult func hasRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output?

    /// Returns the coordinator instance if the specified route without input is currently the root.
    ///
    /// Checks if the given coordinator route without input parameters is currently set as the root
    /// and returns the coordinator instance if found, or `nil` if not.
    ///
    /// - Parameter route: KeyPath to the root transition to check
    /// - Returns: The coordinator instance if it's the current root, `nil` otherwise
    @discardableResult func hasRoot<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output?

    /// Returns the coordinator instance if the specified route with Equatable input is currently the root.
    ///
    /// Checks if the given coordinator route with specific Equatable input parameters is currently
    /// set as the root and returns the coordinator instance if found, or `nil` if not.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition to check
    ///   - input: Equatable input parameters to match
    /// - Returns: The coordinator instance if it's the current root with matching input, `nil` otherwise
    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output?

    /// Returns the coordinator instance if the specified route with custom comparator is currently the root.
    ///
    /// Checks if the given coordinator route with specific input parameters is currently set as the root
    /// and returns the coordinator instance if found, or `nil` if not. Uses a custom comparator for input matching.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the root transition to check
    ///   - input: Input parameters to match
    ///   - comparator: Function to compare input parameters for equality
    /// - Returns: The coordinator instance if it's the current root with matching input, `nil` otherwise
    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output?
}

// MARK: - NavigationCoordinatable Default Implementation

public extension NavigationCoordinatable {
    /// Default implementation returns self as the router storable type.
    ///
    /// This property allows coordinators to be stored in the router system
    /// for navigation operations. Most coordinators can use the default implementation.
    var routerStorable: Self {
        self
    }

    /// The parent coordinator that can dismiss this coordinator.
    ///
    /// This weak reference prevents retain cycles while allowing parent coordinators
    /// to manage their children's lifecycle. Set automatically when coordinators
    /// are added to navigation stacks.
    weak var parent: ChildDismissable? {
        get {
            return stack.parent
        }
        set {
            stack.parent = newValue
        }
    }

    var embeddedInStack: Bool {
        // Only embed NavigationStack if we don't have a parent (i.e., we're a root coordinator)
        // This prevents nested NavigationStack conflicts when coordinators are pushed
        parent == nil
    }

    /// Default implementation returns the view unchanged.
    ///
    /// Override this method to apply global styling, inject environment objects,
    /// or modify the view hierarchy for all screens managed by this coordinator.
    ///
    /// ## Example Override
    /// ```swift
    /// func customize(_ view: AnyView) -> some View {
    ///     view
    ///         .tint(.blue)
    ///         .environmentObject(themeManager)
    /// }
    /// ```
    func customize(_ view: AnyView) -> some View {
        return view
    }

    /// Dismisses a specific child coordinator from the navigation stack.
    ///
    /// Finds the specified coordinator in the navigation stack and removes it along
    /// with any coordinators that were presented after it. This is typically called
    /// automatically when child coordinators request dismissal.
    ///
    /// - Parameters:
    ///   - coordinator: The child coordinator to dismiss
    ///   - action: Optional closure to execute after dismissal completes
    ///
    /// ## Implementation Details
    /// - Searches the stack for the coordinator using its string identifier
    /// - Pops to the position before the coordinator's position
    /// - Triggers an assertion failure if the coordinator is not found
    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)? = nil) {
        guard let value = stack.value.firstIndex(where: { item in
            guard let presentable = item.presentable as? StringIdentifiable else {
                return false
            }

            return presentable.id == coordinator.id
        })
        else {
            assertionFailure("Can not dismiss child when coordinator is top of the stack.")
            return
        }

        popTo(value - 1, action)
    }

    /// Default implementation of coordinator dismissal.
    ///
    /// Requests dismissal from the parent coordinator. This is the standard way
    /// for coordinators to remove themselves from the navigation hierarchy.
    ///
    /// - Parameter action: Optional closure to execute after dismissal completes
    ///
    /// ## Implementation Details
    /// - Requires a valid parent coordinator
    /// - Triggers an assertion failure if no parent is available
    /// - Delegates actual dismissal logic to the parent coordinator
    func dismissCoordinator(_ action: (() -> Void)? = nil) {
        guard let parent = stack.parent else {
            assertionFailure("Can not dismiss coordinator when parent is null.")
            return
        }
        parent.dismissChild(coordinator: self, action: action)
    }

    /// Internal method for handling view appearance at a specific stack index.
    ///
    /// Called when a view at a specific index becomes visible, typically used
    /// for stack synchronization and state management.
    ///
    /// - Parameter int: The stack index that appeared
    internal func appear(_ int: Int) {
        popTo(int, nil)
    }

    /// Removes the last item from the navigation stack.
    ///
    /// Equivalent to pressing the back button once. Removes only the topmost
    /// item from the navigation stack and executes the optional dismissal action.
    ///
    /// - Parameter action: Optional closure to execute after popping completes
    ///
    /// ## Usage
    /// ```swift
    /// coordinator.popLast {
    ///     print("Navigated back")
    /// }
    /// ```
    func popLast(_ action: (() -> Void)? = nil) {
        popTo(stack.value.count - 2, action)
    }

    /// Pops the navigation stack to the specified index.
    ///
    /// ## Index Convention
    /// - `-1`: Pop to root (empty stack)
    /// - `>= 0`: Pop to specific stack position
    internal func popTo(_ int: Int, _ action: (() -> Void)? = nil) {
        print("📤 PopTo: target=\(int), current stack size=\(stack.value.count)")

        if let action = action {
            stack.dismissalAction[int] = action
        }

        // Enhanced bounds checking
        guard int >= -1 else {
            print("⚠️ PopTo: Invalid negative index \(int)")
            return
        }

        guard int + 1 <= stack.value.count else {
            print("⚠️ PopTo: Target index \(int) too large for stack size \(stack.value.count)")
            return
        }

        if int == -1 {
            print("📤 PopTo: Clearing entire stack")
            stack.value = []
            stack.poppedTo.send(-1)
        } else if int >= 0 {
            let newSize = int + 1
            print("📤 PopTo: Keeping first \(newSize) items, removing \(stack.value.count - newSize) items")

            // Additional safety check before using prefix
            guard newSize <= stack.value.count else {
                print("⚠️ PopTo: Calculated new size \(newSize) exceeds current stack size \(stack.value.count)")
                return
            }

            stack.value = Array(stack.value.prefix(newSize))
            stack.poppedTo.send(int)
            print("📤 PopTo: Stack now has \(stack.value.count) items")
        }
    }

    /// Creates the SwiftUI view representation of this coordinator.
    ///
    /// Returns a NavigationCoordinatableView configured as the main coordinator root.
    /// This is the primary entry point for rendering coordinators in SwiftUI.
    ///
    /// - Returns: A SwiftUI view that renders this coordinator's navigation hierarchy
    ///
    /// ## Usage
    /// ```swift
    /// struct ContentView: View {
    ///     let coordinator = MainCoordinator()
    ///
    ///     var body: some View {
    ///         coordinator.view()
    ///     }
    /// }
    /// ```
    func view() -> some View {
        return NavigationCoordinatableView(id: -1, coordinator: self)
    }

    @discardableResult func popToRoot(_ action: (() -> Void)? = nil) -> Self {
        popTo(-1, action)
        return self
    }

    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: @escaping () -> Void
    ) -> Output {
        stack.dismissalAction[stack.value.count - 1] = onDismiss
        return self.route(to: route, input)
    }

    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)
        stack.value.append(
            NavigationStackItem(
                presentationType: transition.type.type,
                presentable: output,
                keyPath: route.hashValue,
                input: input
            )
        )
        output.parent = self
        return output
    }

    @discardableResult func route<Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>,
        onDismiss: @escaping () -> Void
    ) -> Output {
        stack.dismissalAction[stack.value.count - 1] = onDismiss
        return self.route(to: route)
    }

    @discardableResult
    func route<Output: Coordinatable>(to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>) -> Output {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(())
        stack.value.append(
            NavigationStackItem(
                presentationType: transition.type.type,
                presentable: output,
                keyPath: route.hashValue,
                input: nil
            )
        )
        output.parent = self
        return output
    }

    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: @escaping () -> Void
    ) -> Self {
        stack.dismissalAction[stack.value.count - 1] = onDismiss
        return self.route(to: route, input)
    }

    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)
        stack.value.append(
            NavigationStackItem(
                presentationType: transition.type.type,
                presentable: output,
                keyPath: route.hashValue,
                input: input
            )
        )
        return self
    }

    @discardableResult func route<Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>,
        onDismiss: @escaping () -> Void
    ) -> Self {
        stack.dismissalAction[stack.value.count - 1] = onDismiss
        return self.route(to: route)
    }

    @discardableResult func route<Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(())
        stack.value.append(
            NavigationStackItem(
                presentationType: transition.type.type,
                presentable: output,
                keyPath: route.hashValue,
                input: nil
            )
        )
        return self
    }

    @discardableResult private func _focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: (Input, Input) -> Bool)?
    ) throws -> Output {
        guard let value = stack.value.enumerated().first(where: { item in
            guard item.element.keyPath == route.hashValue else {
                return false
            }

            guard let input = input else {
                return true
            }

            guard let compareTo = item.element.input else {
                fatalError()
            }

            return input.comparator(compareTo as! Input, input.value)
        })
        else {
            throw FocusError.routeNotFound
        }

        popTo(value.offset, nil)

        return value.element.presentable as! Output
    }

    @discardableResult private func _focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: (Input, Input) -> Bool)?
    ) throws -> Self {
        guard let value = stack.value.enumerated().first(where: { item in
            guard item.element.keyPath == route.hashValue else {
                return false
            }

            guard let input = input else {
                return true
            }

            guard let compareTo = item.element.input else {
                fatalError()
            }

            return input.comparator(compareTo as! Input, input.value)
        })
        else {
            throw FocusError.routeNotFound
        }

        popTo(value.offset, nil)

        return self
    }

    @discardableResult func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) throws -> Output {
        try _focusFirst(route, nil)
    }

    @discardableResult func focusFirst<Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) throws -> Self {
        try _focusFirst(route, nil)
    }

    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Output {
        try _focusFirst(route, (value: input, comparator: comparator))
    }

    @discardableResult func focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Self {
        try _focusFirst(route, (value: input, comparator: comparator))
    }

    @discardableResult func focusFirst<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Output {
        try _focusFirst(route, (value: input, comparator: { $0 == $1 }))
    }

    @discardableResult func focusFirst<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Self {
        try _focusFirst(route, (value: input, comparator: { $0 == $1 }))
    }

    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Output {
        try _focusFirst(route, nil)
    }

    @discardableResult func focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Self {
        try _focusFirst(route, nil)
    }

    @discardableResult private func _root<Output: Coordinatable, Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Output {
        // Reset stack to allow root switching
        stack.value.removeAll()

        // Ensure root is available before accessing it
        let safeRoot = stack.safeRoot(with: self)

        // Check if we already have the same root with matching input
        let isSameRoot = safeRoot.item.keyPath == route.hashValue
        let hasSameInput: Bool

        if let inputItem = inputItem {
            if let existingInput = safeRoot.item.input {
                hasSameInput = inputItem.comparator(inputItem.input, existingInput as! Input)
            } else {
                hasSameInput = false
            }
        } else {
            hasSameInput = safeRoot.item.input == nil
        }

        // Only return existing root if both route and input match exactly
        if isSameRoot && hasSameInput {
            print("🔄 Root already matches - returning existing coordinator")
            return safeRoot.item.child as! Output
        }

        print("🔄 Creating new root for route \(route.hashValue)")

        // If we're switching to a different root, we need to handle it properly
        if !isSameRoot {
            print("🔄 Root switch detected: from \(safeRoot.item.keyPath) to \(route.hashValue)")
        }

        let output: Output

        if let input = inputItem?.input {
            output = self[keyPath: route].closure(self)(input)
        } else {
            output = self[keyPath: route].closure(self)(() as! Input)
        }

        // Always create a new NavigationRootItem to trigger proper updates
        safeRoot.item = NavigationRootItem(
            keyPath: route.hashValue,
            input: inputItem?.input,
            child: output
        )

        print("🔄 Root updated to keyPath \(route.hashValue) with coordinator \(type(of: output))")
        return output
    }

    @discardableResult private func _root<Output: View, Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Self {
        // Reset stack to allow root switching
        stack.value.removeAll()

        // Ensure root is available before accessing it
        let safeRoot = stack.safeRoot(with: self)

        // Check if we already have the same root with matching input
        let isSameRoot = safeRoot.item.keyPath == route.hashValue
        let hasSameInput: Bool

        if let inputItem = inputItem {
            if let existingInput = safeRoot.item.input {
                hasSameInput = inputItem.comparator(inputItem.input, existingInput as! Input)
            } else {
                hasSameInput = false
            }
        } else {
            hasSameInput = safeRoot.item.input == nil
        }

        // Only return early if both route and input match exactly
        if isSameRoot && hasSameInput {
            print("🔄 Root view already matches - returning self")
            return self
        }

        print("🔄 Creating new root view for route \(route.hashValue)")

        // If we're switching to a different root, we need to handle it properly
        if !isSameRoot {
            print("🔄 Root view switch detected: from \(safeRoot.item.keyPath) to \(route.hashValue)")
        }

        let output: Output

        if let input = inputItem?.input {
            output = self[keyPath: route].closure(self)(input)
        } else {
            output = self[keyPath: route].closure(self)(() as! Input)
        }

        // Always create a new NavigationRootItem to trigger proper updates
        safeRoot.item = NavigationRootItem(
            keyPath: route.hashValue,
            input: inputItem?.input,
            child: AnyView(output)
        )

        print("🔄 Root view updated to keyPath \(route.hashValue)")
        return self
    }

    @discardableResult func root<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output {
        _root(route, inputItem: nil)
    }

    @discardableResult func root<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Self {
        _root(route, inputItem: nil)
    }

    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output {
        _root(route, inputItem: nil)
    }

    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Self {
        _root(route, inputItem: nil)
    }

    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output {
        _root(route, inputItem: (input, comparator))
    }

    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Self {
        _root(route, inputItem: (input, comparator))
    }

    @discardableResult func root<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output {
        _root(route, inputItem: (input, { $0 == $1 }))
    }

    @discardableResult func root<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Self {
        _root(route, inputItem: (input, { $0 == $1 }))
    }

    private func _isRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Bool {
        // Ensure root is available before accessing it
        let safeRoot = stack.safeRoot(with: self)

        guard safeRoot.item.keyPath == route.hashValue else {
            return false
        }

        guard let inputItem = inputItem else {
            return true
        }

        guard let compareTo = safeRoot.item.input else {
            fatalError()
        }

        return inputItem.comparator(compareTo as! Input, inputItem.input)
    }

    private func _isRoot<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Bool {
        // Ensure root is available before accessing it
        let safeRoot = stack.safeRoot(with: self)

        guard safeRoot.item.keyPath == route.hashValue else {
            return false
        }

        guard let inputItem = inputItem else {
            return true
        }

        guard let compareTo = safeRoot.item.input else {
            fatalError()
        }

        return inputItem.comparator(compareTo as! Input, inputItem.input)
    }

    private func _hasRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Output? {
        return _isRoot(route, inputItem: inputItem) ? (stack.safeRoot(with: self).item.child as! Output) : nil
    }

    @discardableResult func isRoot<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Bool {
        return _isRoot(route, inputItem: nil)
    }

    @discardableResult func isRoot<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Bool {
        return _isRoot(route, inputItem: nil)
    }

    @discardableResult func isRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool {
        return _isRoot(route, inputItem: nil)
    }

    @discardableResult func isRoot<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool {
        return _isRoot(route, inputItem: nil)
    }

    @discardableResult func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool {
        return _isRoot(route, inputItem: (input: input, comparator: { $0 == $1 }))
    }

    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool {
        return _isRoot(route, inputItem: (input: input, comparator: { $0 == $1 }))
    }

    func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool {
        return _isRoot(route, inputItem: (input: input, comparator: comparator))
    }

    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool {
        return _isRoot(route, inputItem: (input: input, comparator: comparator))
    }

    @discardableResult func hasRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output? {
        return _hasRoot(route, inputItem: nil)
    }

    @discardableResult func hasRoot<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output? {
        return _hasRoot(route, inputItem: nil)
    }

    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output? {
        return _hasRoot(route, inputItem: (input: input, comparator: { $0 == $1 }))
    }

    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output? {
        return _hasRoot(route, inputItem: (input: input, comparator: comparator))
    }

    // MARK: - Child Coordinator Routes

    /// Routes to a ChildCoordinatable destination with input parameters.
    /// Child coordinators share the same navigation stack and can control their portion of it.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the route transition that creates the target child coordinator
    ///   - input: Parameters passed to the child coordinator creation closure
    /// - Returns: The newly created child coordinator instance
    ///
    /// ## Example
    /// ```swift
    /// let detailChild = coordinator.routeToChild(to: \.detailChild, detailData)
    /// ```
    @discardableResult func routeToChild<Input, Output: ChildCoordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output where Output.Parent == Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)

        // Create the navigation stack item for the child's root
        let childRootItem = NavigationStackItem(
            presentationType: transition.type.type,
            presentable: output,
            keyPath: route.hashValue,
            input: input
        )

        // Add to stack
        stack.value.append(childRootItem)

        // Set up parent-child relationship
        output.parent = self

        return output
    }

    /// Routes to a ChildCoordinatable destination without input parameters.
    ///
    /// - Parameter route: KeyPath to the route transition that creates the target child coordinator
    /// - Returns: The newly created child coordinator instance
    @discardableResult func routeToChild<Output: ChildCoordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Output where Output.Parent == Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(())

        // Create the navigation stack item for the child's root
        let childRootItem = NavigationStackItem(
            presentationType: transition.type.type,
            presentable: output,
            keyPath: route.hashValue,
            input: nil
        )

        // Add to stack
        stack.value.append(childRootItem)

        // Set up parent-child relationship
        output.parent = self

        return output
    }

    /// Routes to multiple coordinators by sharing the navigation stack.
    /// This allows pushing multiple coordinators without nested NavigationStack issues.
    ///
    /// - Parameters:
    ///   - route: KeyPath to the route transition that creates a NavigationCoordinatable
    ///   - input: Parameters passed to the coordinator creation closure
    /// - Returns: The newly created coordinator that shares this coordinator's stack
    @discardableResult func routeShared<Input, Output: NavigationCoordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output {
        let transition = self[keyPath: route]
        let coordinator = transition.closure(self)(input)

        // Create the navigation stack item
        let sharedItem = NavigationStackItem(
            presentationType: transition.type.type,
            presentable: coordinator,
            keyPath: route.hashValue,
            input: input
        )

        // Add to stack - this coordinator will share our stack
        stack.value.append(sharedItem)

        // Set up parent-child relationship but don't give it its own NavigationStack
        coordinator.parent = self

        return coordinator
    }

    /// Routes to multiple coordinators by sharing the navigation stack (no input).
    @discardableResult func routeShared<Output: NavigationCoordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Output {
        let transition = self[keyPath: route]
        let coordinator = transition.closure(self)(())

        // Create the navigation stack item
        let sharedItem = NavigationStackItem(
            presentationType: transition.type.type,
            presentable: coordinator,
            keyPath: route.hashValue,
            input: nil
        )

        // Add to stack - this coordinator will share our stack
        stack.value.append(sharedItem)

        // Set up parent-child relationship but don't give it its own NavigationStack
        coordinator.parent = self

        return coordinator
    }
}
