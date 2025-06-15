import Foundation
import SwiftUI

import Stinsen

final class HomeCoordinator: NavigationCoordinatable {
    @Root(makeStart) var start

    var stack = NavigationStack(initial: \HomeCoordinator.start)
    let todosStore: TodosStore

    init(todosStore: TodosStore) {
        self.todosStore = todosStore
    }

    deinit {
        print("De-init HomeCoordinator")
    }
}
