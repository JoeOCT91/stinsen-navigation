import Foundation
import SwiftUI

/// A SwiftUI view that renders ViewWrapperCoordinator instances.
///
/// This view handles the presentation of wrapped coordinators while maintaining
/// type safety and avoiding AnyView type erasure. It directly uses the child
/// coordinator's PresentedView type for optimal performance.
struct ViewWrapperCoordinatorView<U: Coordinatable, T: ViewWrapperCoordinator<U, V>, V: View>: View
{
    var coordinator: T
    private let childView: U.PresentedView
    private let view: (U.PresentedView) -> V

    /// Initializes the view with a coordinator and view transformation closure.
    ///
    /// - Parameters:
    ///   - coordinator: The ViewWrapperCoordinator to render
    ///   - view: A closure that transforms the child view into the wrapper view
    init(coordinator: T, @ViewBuilder _ view: @escaping (U.PresentedView) -> V) {
        self.coordinator = coordinator
        self.view = view
        self.childView = coordinator.child.view()
    }

    var body: some View {
        view(childView)
    }
}
