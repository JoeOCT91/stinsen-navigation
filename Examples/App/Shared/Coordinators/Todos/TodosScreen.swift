import Foundation
import SwiftUI
import Stinsen

struct TodosScreen: View {
    @ObservedObject private var todosStore: TodosStore
    @EnvironmentObject private var todosRouter: TodosCoordinator.Router

    init(todosStore: TodosStore) {
        self.todosStore = todosStore
    }

    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    button
                }
            }
    }

    var content: some View {
        ScrollView {
            VStack {
                if todosStore.all.isEmpty {
                    InfoText("You have no stored todos.")
                }

                ForEach(todosStore.all) { todo in
                    Button(todo.name) {
                        todosRouter.route(to: \.todo, todo.id)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle("My ToDos Screen")
        }
    }

    var button: some View {
        Button(
            action: {
                todosRouter.route(to: \.createTodo)
            },
            label: {
                Image(systemName: "folder.badge.plus")
            }
        )
    }
}

struct TodosScreen_Previews: PreviewProvider {
    static var previews: some View {
        TodosScreen(todosStore: TodosStore(user: User(username: "user@example.com", accessToken: UUID().uuidString)))
    }
}
