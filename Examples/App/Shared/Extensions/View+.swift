import SwiftUI

extension View {
    @ViewBuilder
    func navigationTitle(with title: String) -> some View {
        self.navigationBarTitle(title)
    }
}
