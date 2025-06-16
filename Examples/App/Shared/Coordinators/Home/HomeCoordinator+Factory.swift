import Foundation
import SwiftUI
import Stinsen

extension HomeCoordinator {
     func makeStart() -> some View {
        HomeScreen(todosStore: todosStore)
    }
}
