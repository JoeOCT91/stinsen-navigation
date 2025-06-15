import Foundation
import SwiftUI

/// A concrete wrapper for NavigationStack to avoid generic type issues.
public struct NavigationStackWrapper<Content: View>: View {
    let content: Content

    public var body: some View {
        SwiftUI.NavigationStack {
            content
        }
    }
}

/// A coordinator that wraps child coordinators in a SwiftUI NavigationStack.
///
/// NavigationViewCoordinator provides a convenient way to wrap any coordinator
/// in a NavigationStack, enabling navigation functionality while maintaining
/// type safety and avoiding AnyView type erasure.
///
/// ## Usage Example
/// ```swift
/// let navigationCoordinator = NavigationViewCoordinator(childCoordinator)
/// ```
public class NavigationViewCoordinator<T: Coordinatable>: ViewWrapperCoordinator<
    T, NavigationStackWrapper<T.PresentedView>
>
{

    /// Initializes a NavigationViewCoordinator that wraps the child in a NavigationStack.
    ///
    /// - Parameter childCoordinator: The coordinator to wrap in a NavigationStack
    public init(_ childCoordinator: T) {
        super.init(childCoordinator) { childView in
            NavigationStackWrapper(content: childView)
        }
    }

    @available(
        *, unavailable,
        message: "NavigationViewCoordinator automatically provides NavigationStack wrapping"
    )
    public override init(
        _ childCoordinator: T,
        _ view: @escaping (T) -> (T.PresentedView) -> NavigationStackWrapper<T.PresentedView>
    ) {
        fatalError("NavigationViewCoordinator automatically provides NavigationStack wrapping")
    }
}
