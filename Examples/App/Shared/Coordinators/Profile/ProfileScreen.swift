import Foundation
import SwiftUI
import Stinsen

struct ProfileScreen: View {
    private let user: User

    init(user: User) {
        self.user = user
    }

    var body: some View {
        ScrollView {
            VStack {
                switch AuthenticationService.shared.status {
                case .authenticated(let user):
                    InfoText("Currently logged in as \(user.username)")
                case .unauthenticated:
                    EmptyView() // shouldn't happen
                }

                Spacer(minLength: 16)
                RoundedButton("Logout") {
                    AuthenticationService.shared.status = .unauthenticated
                }
            }
        }
    }
}
