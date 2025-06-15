import Foundation
import Stinsen
import SwiftUI

extension UnauthenticatedCoordinator {
    func makeRegistration() -> RegistrationCoordinator {
        return RegistrationCoordinator(services: unauthenticatedServices)
    }

    func makeForgotPassword() -> some View {
        ForgotPasswordScreen(services: unauthenticatedServices)
    }

    func makeStart() -> some View {
        LoginScreen(services: unauthenticatedServices)
    }
}
