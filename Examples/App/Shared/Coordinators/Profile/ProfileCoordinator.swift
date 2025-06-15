import Foundation
import Stinsen
import SwiftUI

final class ProfileCoordinator: NavigationCoordinatable {
    var stack = NavigationStack(initial: \ProfileCoordinator.start)

    @Root(makeStart) var start

    let user: User

    init(user: User) {
        self.user = user
    }

    deinit {
        print("Deinit ProfileCoordinator")
    }
}
