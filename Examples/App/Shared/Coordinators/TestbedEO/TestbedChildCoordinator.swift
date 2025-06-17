import Foundation
import Stinsen
import SwiftUI

/// A child coordinator that demonstrates the new @ChildRoute functionality
/// This coordinator uses @ChildRoute to route through its parent's navigation stack
final class TestbedChildCoordinator: ChildCoordinatable {
    typealias Parent = TestbedEnvironmentObjectCoordinator

    weak var parent: TestbedEnvironmentObjectCoordinator?
    private let childId: Int

    // Use the new @ChildRoot property wrapper
    @ChildRoot(makeMainView) var root

    // Access the root manager through the projected value
    var rootManager: ChildRootManager<TestbedChildCoordinator> {
        return $root
    }

    // MARK: - Child Routes (using @ChildRoute)

    /// Routes that will be executed on the parent's navigation stack
    @ChildRoute<TestbedChildCoordinator, Void, AnyView>(.push) var mainView = makeMainView
    @ChildRoute<TestbedChildCoordinator, Void, AnyView>(.push) var childDetailView = makeChildDetailView
    @ChildRoute<TestbedChildCoordinator, Void, AnyView>(.modal) var childModalView = makeChildModalView
    @ChildRoute<TestbedChildCoordinator, Void, TestbedChildCoordinator>(.push) var anotherChild = makeAnotherChild

    /// Initialize with parent and unique identifier
    init(parent: TestbedEnvironmentObjectCoordinator, childId: Int) {
        self.parent = parent
        self.childId = childId
    }

    // MARK: - Factory Methods for Child Routes

    /// Creates the main view for this child coordinator
    func makeMainView() -> some View {
        TestbedChildScreen(coordinator: self)
    }

    /// Creates a detail view for this child coordinator
    func makeChildDetailView() -> some View {
        TestbedChildScreen(coordinator: self)
    }

    /// Creates a modal view for this child coordinator
    func makeChildModalView() -> some View {
        NavigationView {
            VStack {
                Text("Child Modal View")
                    .font(.title)
                Text("Child ID: \(self.childId)")
                    .font(.caption)

                Button("Dismiss") {

                }
                .padding()
            }
            .navigationTitle("Child Modal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Creates another child coordinator
    func makeAnotherChild() -> TestbedChildCoordinator {
        TestbedChildCoordinator(parent: parent!, childId: childId + 1)
    }

    // MARK: - Navigation Methods (using @ChildRoute)

    /// Pushes another child coordinator using the new child route system
    func pushAnotherChild() {
        route(anotherChild)
    }

    /// Pushes a regular view using the new child route system
    func pushView() {
        route(childDetailView)
    }

    /// Shows a modal using the new child route system
    func showModal() {
        route(childModalView)
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
