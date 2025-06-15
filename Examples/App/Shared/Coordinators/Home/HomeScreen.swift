import Foundation
import Stinsen
import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var authenticatedRouter: AuthenticatedCoordinator.Router
    @ObservedObject private var todosStore: TodosStore

    var body: some View {
        ScrollView {
            if todosStore.favorites.isEmpty {
                InfoText(
                    "Welcome to Stinsenapp! If you had any todo's marked as your favorites, they would show up on this page."
                )
            } else {
                InfoText("Welcome to Stinsenapp! Here are your favorite todos:")
                VStack {
                    ForEach(todosStore.favorites) { todo in
                        Button(todo.name) {
                            let todosCoordinator =
                                authenticatedRouter
                                .focusFirst(\.$todos)
                                .child



                            DispatchQueue.main.async {
                                todosCoordinator
                                    .popToRoot()
                                    .route(to: \.todo, todo.id)
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle(with: "Home")
    }

    init(todosStore: TodosStore) {
        self.todosStore = todosStore
    }
}
