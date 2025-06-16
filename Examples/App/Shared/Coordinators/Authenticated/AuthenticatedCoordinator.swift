import Stinsen
import SwiftUI

final class AuthenticatedCoordinator: TabCoordinatable {
    // Use the new type-safe TabChild with route descriptors
    let child: TabChild<AuthenticatedCoordinator>

    let todosStore: TodosStore
    let user: User

    // Clean syntax with @TabRoute
    @TabRoute(tabItem: makeHomeTab) var home = makeHome
    @TabRoute(tabItem: makeTodosTab) var todos = makeTodos
    @TabRoute(tabItem: makeProfileTab) var profile = makeProfile
    @TabRoute(tabItem: makeTestbedTab, onTapped: onTestbedTapped) var testbed = makeTestbed

    init(user: User) {
        self.todosStore = TodosStore(user: user)
        self.user = user

        // Initialize with type‑safe route descriptors
        self.child = TabChild(
            routeDescriptors: [
                TabRouteDescriptor(\.$home),
                TabRouteDescriptor(\.$todos),
                TabRouteDescriptor(\.$profile),
                TabRouteDescriptor(\.$testbed),
            ]
        )
    }

    func customize(_ view: AnyView) -> some View {
        view
            .accentColor(Color("AccentColor"))

    }

    deinit {
        print("De-init AuthenticatedCoordinator")
    }
}
