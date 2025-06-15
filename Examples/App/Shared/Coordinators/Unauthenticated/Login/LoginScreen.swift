import Foundation
import SwiftUI

import Stinsen

struct LoginScreen: View {
    @EnvironmentObject private var mainRouter: MainCoordinator.Router
    @EnvironmentObject private var unauthenticatedRouter: UnauthenticatedCoordinator.Router

    @State private var username: String = "user@example.com"
    @State private var password: String = "password"

    private let services: UnauthenticatedServices

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    Spacer()

                    headView

                    RoundedTextField(
                        "Username",
                        text: $username
                    )

                    RoundedTextField(
                        "Password",
                        text: $password,
                        secure: true
                    )

                    RoundedButton("Login") {
                        services.login.login(
                            username: username,
                            password: password,
                            callback: nil
                        )
                    }

                    RoundedButton("Register", style: .secondary) {
                        unauthenticatedRouter.route(to: \.registration)
                    }

                    RoundedButton("Forgot your password?", style: .tertiary) {
                        unauthenticatedRouter.route(to: \.forgotPassword)
                    }

                    Spacer()
                }
                .frame(minHeight: proxy.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Login Screen")
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var headView: some View {
        Text("Welcome to StinsenApp. This app's purpose is to showcase many of the features Stinsen has to offer. Feel free to look around!")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }

    init(services: UnauthenticatedServices) {
        self.services = services
    }
}
