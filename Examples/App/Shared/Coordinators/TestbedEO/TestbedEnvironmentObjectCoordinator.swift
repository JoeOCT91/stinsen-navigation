import Foundation
import SwiftUI

import Stinsen

final class TestbedEnvironmentObjectCoordinator: NavigationCoordinatable {
    var stack = NavigationStack(initial: \TestbedEnvironmentObjectCoordinator.start)

    @Root var start = makeStart
    @NavigationRoute(.modal) var modalScreen = makeModalScreen
    @NavigationRoute(.push) var pushScreen = makePushScreen
    @NavigationRoute(.modal) var modalCoordinator = makeModalCoordinator
    @NavigationRoute(.push) var pushCoordinator = makePushCoordinator

    deinit {
        print("Deinit TestbedEnvironmentObjectCoordinator")
    }
}
