import Stinsen
import SwiftUI

extension AuthenticatedCoordinator {
    func makeTestbed() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator()
    }

    func onTestbedTapped(isRepeat: Bool, coordinator: TestbedEnvironmentObjectCoordinator) {
        if isRepeat {
            coordinator.popToRoot()
        }
    }

    func makeHome() -> HomeCoordinator {
        return HomeCoordinator(todosStore: todosStore)
    }

    func makeTodos() -> TodosCoordinator {
        return TodosCoordinator(todosStore: todosStore)
    }

    func makeProfile() -> ProfileCoordinator {
        return ProfileCoordinator(user: user)
    }

    @ViewBuilder
    func makeHomeTab(isActive: Bool) -> some View {
        Image(systemName: "house" + (isActive ? ".fill" : ""))
        Text("Home")
    }

    @ViewBuilder
    func makeTodosTab(isActive: Bool) -> some View {
        Image(systemName: "folder" + (isActive ? ".fill" : ""))
        Text("Todos")
    }

    @ViewBuilder
    func makeProfileTab(isActive: Bool) -> some View {
        Image(systemName: "person.crop.circle" + (isActive ? ".fill" : ""))
        Text("Profile")
    }

    @ViewBuilder
    func makeTestbedTab(isActive: Bool) -> some View {
        Image(systemName: "bed.double" + (isActive ? ".fill" : ""))
        Text("Testbed")
    }
}
