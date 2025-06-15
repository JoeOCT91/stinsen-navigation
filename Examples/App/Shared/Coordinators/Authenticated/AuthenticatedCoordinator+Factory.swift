import Stinsen
import SwiftUI

extension AuthenticatedCoordinator {
    func makeTestbed() -> NavigationViewCoordinator<TestbedEnvironmentObjectCoordinator> {
        return NavigationViewCoordinator(TestbedEnvironmentObjectCoordinator())
    }

    func onTestbedTapped(
        isRepeat: Bool, coordinator: NavigationViewCoordinator<TestbedEnvironmentObjectCoordinator>
    ) {
        if isRepeat {
            coordinator.child.popToRoot()
        }
    }

    func makeHome() -> NavigationViewCoordinator<HomeCoordinator> {
        return NavigationViewCoordinator(HomeCoordinator(todosStore: todosStore))
    }



    func makeProfile() -> NavigationViewCoordinator<ProfileCoordinator> {
        return NavigationViewCoordinator(ProfileCoordinator(user: user))
    }

    func makeTodos() -> TodosCoordinator {
        return (TodosCoordinator(todosStore: todosStore))
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
