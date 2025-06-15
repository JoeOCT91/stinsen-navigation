import Foundation
import Stinsen
import SwiftUI

final class TodosCoordinator: NavigationCoordinatable {
    var stack = NavigationStack(initial: \TodosCoordinator.start)

    @Root var start = makeStart
    @NavigationRoute(.push) var todo = makeTodo
    @NavigationRoute(.modal) var createTodo = makeCreateTodo

    let todosStore: TodosStore

    init(todosStore: TodosStore) {
        self.todosStore = todosStore
    }

    deinit {
        print("Deinit TodosCoordinator")
    }
}
