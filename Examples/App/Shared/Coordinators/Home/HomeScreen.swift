import Foundation
import Stinsen
import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var authenticatedRouter: AuthenticatedCoordinator.Router
    @ObservedObject private var todosStore: TodosStore

    init(todosStore: TodosStore) {
        self.todosStore = todosStore
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    headView

                    ForEach(todosStore.favorites) { todo in
                        Button(todo.name) {
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle("Home")
    }


    private var headView: some View {
        Text(
            todosStore.favorites.isEmpty ?
            "Welcome to Stinsen-app! If you had any todo's marked as your favorites, they would show up on this page." :
                "Welcome to Stinsen-app! Here are your favorite todos:"
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
