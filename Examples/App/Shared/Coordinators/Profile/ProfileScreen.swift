import Foundation
import SwiftUI
import Stinsen

struct ProfileScreen: View {
    private let user: User

    init(user: User) {
        self.user = user
    }

    var body: some View {
        GeometryReader { geometryProxy in
            ScrollView {
                VStack(spacing: 16) {
                    Spacer()

                    switch AuthenticationService.shared.status {
                    case .authenticated(let user):
                        InfoText("Currently logged in as \(user.username)")
                    case .unauthenticated:
                        EmptyView() // shouldn't happen
                    }

                    RoundedButton("Logout") {
                        AuthenticationService.shared.status = .unauthenticated
                    }

                    Spacer()
                }
                .padding()
                .frame(minHeight: geometryProxy.size.height)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
