import Foundation
import Stinsen
import SwiftUI

final class MainCoordinator: NavigationCoordinatable {
    var stack: Stinsen.NavigationStack<MainCoordinator>

    @Root var unauthenticated = makeUnauthenticated
    @Root var authenticated = makeAuthenticated

    init() {
        switch AuthenticationService.shared.status {
        case let .authenticated(user):
            stack = NavigationStack(initial: \MainCoordinator.authenticated, user)
        case .unauthenticated:
            stack = NavigationStack(initial: \MainCoordinator.unauthenticated)
        }
    }

    @ViewBuilder
    func sharedView(_ view: AnyView) -> some View {
        view
            .onReceive(AuthenticationService.shared.$status) { status in
                print("🔄 MainCoordinator received auth status change: \(status)")
                switch status {
                case .unauthenticated:
                    print("🔄 Switching to unauthenticated root")
                    // Create new stack with unauthenticated root
                    self.stack = NavigationStack(initial: \MainCoordinator.unauthenticated)
                case let .authenticated(user):
                    print("🔄 Switching to authenticated root for user: \(user.username)")
                    // Create new stack with authenticated root and user input
                    self.stack = NavigationStack(initial: \MainCoordinator.authenticated, user)
                }
            }
    }

    func customize(_ view: AnyView) -> some View {
        sharedView(view)
            .accentColor(Color("AccentColor"))
    }

    deinit {
        print("De-init MainCoordinator")
    }
}
