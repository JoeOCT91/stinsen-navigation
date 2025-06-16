import Foundation
import Stinsen
import SwiftUI

extension TestbedEnvironmentObjectCoordinator {
    func makePushScreen() -> some View {
        TestbedEnvironmentObjectScreen()
    }

    func makeModalScreen() -> some View {
        NavigationView {
            TestbedEnvironmentObjectScreen()
        }
    }

    func makePushCoordinator() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator()
    }

    func makeModalCoordinator() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator()
    }

    func makeFullScreenScreen() -> some View {
        NavigationView {
            TestbedEnvironmentObjectScreen()
        }
    }

    func makeFullScreenCoordinator() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator()
    }

    func makeStart() -> some View {
        TestbedEnvironmentObjectScreen()
    }

    func makeTestbedChild(childId: Int) -> TestbedChildCoordinator {
        return TestbedChildCoordinator(parent: self, childId: childId)
    }
}
