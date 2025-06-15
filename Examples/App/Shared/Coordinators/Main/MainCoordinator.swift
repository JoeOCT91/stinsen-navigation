import Foundation
import Stinsen
import SwiftUI

final class MainCoordinator: NavigationCoordinatable {
    lazy var stack: Stinsen.NavigationStack<MainCoordinator> = {
        switch AuthenticationService.shared.status {
        case let .authenticated(user):
            return NavigationStack(initial: \MainCoordinator.authenticated, user)
        case .unauthenticated:
            return NavigationStack(initial: \MainCoordinator.unauthenticated)
        }
    }()

    @Root(makeUnauthenticated) var unauthenticated
    @Root(makeAuthenticated) var authenticated

    init() { }

    @ViewBuilder
    func sharedView(_ view: AnyView) -> some View {
        view
            .onReceive(AuthenticationService.shared.$status) { status in
                print("🔄 MainCoordinator received auth status change: \(status)")
                switch status {
                case .unauthenticated:
                    print("🔄 Switching to unauthenticated root")
                    // Create new stack
                    self.stack = NavigationStack(initial: \MainCoordinator.unauthenticated)
                case let .authenticated(user):
                    print("🔄 Switching to authenticated root for user: \(user.username)")
                    // Create new stack with user input
                    self.root(\MainCoordinator.authenticated, user)
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
