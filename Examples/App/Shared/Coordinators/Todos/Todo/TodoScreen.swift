import Foundation
import SwiftUI
import Stinsen

struct TodoScreen: View {
    @EnvironmentObject private var todosRouter: TodosCoordinator.Router
    @ObservedObject private var todosStore: TodosStore

    private let todoId: UUID

    init(todosStore: TodosStore, todoId: UUID) {
        self.todoId = todoId
        self.todosStore = todosStore
    }

    var body: some View {
        ScrollView {
            InfoText("This is the details screen for your todo.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("ToDo Screen")
    }

    var button: some View {
        Button(
            action: {
                todosStore[todoId].isFavorite.toggle()
            },
            label: {
                Image(systemName: "star" + (todosStore[todoId].isFavorite ? ".fill" : ""))
            }
        )
    }
}

struct TodoScreen_Previews: PreviewProvider {
    static var previews: some View {
        TodoScreen(todosStore: TodosStore(user: User(username: "user@example.com", accessToken: UUID().uuidString)), todoId: UUID())
    }
}
