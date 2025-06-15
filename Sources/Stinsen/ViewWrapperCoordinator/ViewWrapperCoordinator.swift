import Foundation
import SwiftUI

/// A coordinator that wraps child coordinators with custom view transformations.
///
/// ViewWrapperCoordinator allows you to apply view modifiers or wrap child coordinators
/// in custom container views while maintaining type safety and avoiding AnyView type erasure.
///
/// ## Usage Example
/// ```swift
/// // Wrap a coordinator in a NavigationStack
/// let wrappedCoordinator = ViewWrapperCoordinator(childCoordinator) { childView in
///     NavigationStack {
///         childView
///     }
/// }
/// ```
open class ViewWrapperCoordinator<T: Coordinatable, V: View>: Coordinatable {
    public let child: T
    public weak var parent: ChildDismissable?
    private let viewFactory: (T) -> (T.PresentedView) -> V

    /// Initializes a ViewWrapperCoordinator with a view transformation closure.
    ///
    /// - Parameters:
    ///   - childCoordinator: The child coordinator to wrap
    ///   - view: A closure that transforms the child's view into the wrapper view
    public init(_ childCoordinator: T, @ViewBuilder _ view: @escaping (T.PresentedView) -> V) {
        self.child = childCoordinator
        self.viewFactory = { _ in { childView in view(childView) } }
        self.child.parent = self
    }

    /// Initializes a ViewWrapperCoordinator with a coordinator-aware view transformation.
    ///
    /// - Parameters:
    ///   - childCoordinator: The child coordinator to wrap
    ///   - view: A closure that receives both the coordinator and child view
    public init(_ childCoordinator: T, _ view: @escaping (T) -> (T.PresentedView) -> V) {
        self.child = childCoordinator
        self.viewFactory = view
        self.child.parent = self
    }

    public func view() -> some View {
        ViewWrapperCoordinatorView(coordinator: self, viewFactory(child))
    }

    public func dismissChild<CoordinatorType: Coordinatable>(
        coordinator: CoordinatorType, action: (() -> Void)?
    ) {
        guard let parent = self.parent else {
            assertionFailure("Can not dismiss a coordinator since no coordinator is presented.")
            return
        }

        parent.dismissChild(coordinator: self, action: action)
    }
}
