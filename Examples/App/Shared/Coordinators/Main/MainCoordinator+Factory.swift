import Foundation
import SwiftUI
import Stinsen

extension MainCoordinator {
    func makeUnauthenticated() -> UnauthenticatedCoordinator {
        return UnauthenticatedCoordinator()
    }
    
    func makeAuthenticated(user: User) -> AuthenticatedCoordinator {
        return AuthenticatedCoordinator(user: user)
    }
}
