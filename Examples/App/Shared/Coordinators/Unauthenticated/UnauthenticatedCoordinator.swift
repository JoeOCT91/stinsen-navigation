import Foundation
import SwiftUI

import Stinsen

final class UnauthenticatedCoordinator: NavigationCoordinatable {
    var stack = NavigationStack(initial: \UnauthenticatedCoordinator.start)
    let unauthenticatedServices = UnauthenticatedServices()

    @Root(makeStart) var start
    @NavigationRoute(.push) var forgotPassword = makeForgotPassword
    @NavigationRoute(.push) var registration = makeRegistration

    deinit {
        print("Deinit UnauthenticatedCoordinator")
    }
}
