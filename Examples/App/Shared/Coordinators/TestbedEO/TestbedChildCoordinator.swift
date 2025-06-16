import Foundation
import Stinsen
import SwiftUI

/// A child coordinator that demonstrates the ChildCoordinatable protocol
/// This coordinator shares the navigation stack with its parent (TestbedEnvironmentObjectCoordinator)
final class TestbedChildCoordinator: ChildCoordinatable {
    typealias Parent = TestbedEnvironmentObjectCoordinator

    weak var parent: TestbedEnvironmentObjectCoordinator?
    private let childId: Int

    /// The root path points to the property that creates this coordinator's root view
    var rootPath: PartialKeyPath<TestbedChildCoordinator> {
        return \.rootView
    }

    /// Initialize with parent and unique identifier
    init(parent: TestbedEnvironmentObjectCoordinator, childId: Int) {
        self.parent = parent
        self.childId = childId
    }

    /// Creates the root view for this child coordinator
    var rootView: some View {
        TestbedChildScreen(coordinator: self)
    }

    /// Push another child coordinator to demonstrate multiple children
    func pushAnotherChild() {
        parent?.routeToChild(to: \.testbedChild, childId + 1)
    }

    /// Push a regular view
    func pushView() {
        parent?.route(to: \.pushScreen)
    }

    /// Dismiss this child coordinator
    func dismissSelf() {
        parent?.dismissChild(coordinator: self)
    }

    deinit {
        print("Deinit TestbedChildCoordinator \(childId)")
    }
}

// MARK: - Coordinatable Conformance

extension TestbedChildCoordinator: Coordinatable {
    var id: String {
        return "TestbedChildCoordinator-\(childId)"
    }
}
