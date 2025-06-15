import Foundation
import Stinsen
import SwiftUI

final class MainCoordinator: NavigationCoordinatable {
    var stack: Stinsen.NavigationStack<MainCoordinator>

    @Root var unauthenticated = makeUnauthenticated
    @Root var authenticated = makeAuthenticated

    @ViewBuilder func sharedView(_ view: AnyView) -> some View {
        view
//            .onReceive(
//                AuthenticationService.shared.$status,
//                perform: { status in
//                    print("🔄 MainCoordinator received auth status change: \(status)")
//                    switch status {
//                    case .unauthenticated:
//                        print("🔄 Switching to unauthenticated root")
//                        self.root(\.$unauthenticated)
//                    case .authenticated(let user):
//                        print("🔄 Switching to authenticated root for user: \(user.username)")
//                        self.root(\.authenticated, user)
//                    }
//                })
    }

    @ViewBuilder func customize(_ view: AnyView) -> some View {
        #if os(iOS)
            sharedView(view)
//                .onOpenURL(perform: { url in
//                    if let coordinator = self.hasRoot(\.authenticated) {
//                        do {
//                            let deepLink = try DeepLink(
//                                url: url, todosStore: coordinator.todosStore)
//
//                            switch deepLink {
//                            case .todo(let id):
//                                coordinator
//                            //                                    .focusFirst(\.todos)
//                            //                                    .child
//                            //                                    .route(to: \.todo, id)
//                            }
//                        } catch {
//                            print(error.localizedDescription)
//                        }
//                    }
//                })
                    .accentColor(Color("AccentColor"))
        #elseif os(macOS)
            sharedView(view)
                .accentColor(Color("AccentColor"))
        #else
            sharedView(view)
        #endif
    }

    deinit {
        print("Deinit MainCoordinator")
    }

    init() {
        switch AuthenticationService.shared.status {
        case let .authenticated(user):
            stack = NavigationStack(initial: \MainCoordinator.authenticated, user)
        case .unauthenticated:
            stack = NavigationStack(initial: \MainCoordinator.unauthenticated)
        }
    }
}
