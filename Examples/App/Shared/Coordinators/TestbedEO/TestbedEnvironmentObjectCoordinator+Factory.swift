import Foundation
import Stinsen
import SwiftUI

struct FullScreenTestView: View {
    @EnvironmentObject var testbed: TestbedEnvironmentObjectCoordinator.Router

    var body: some View {
        ZStack {
            // Full screen background
            LinearGradient(
                gradient: Gradient(colors: [.purple, .blue, .black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)

            VStack(spacing: 30) {
                Text("🚀 FULL SCREEN MODE 🚀")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("This is a full screen presentation")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    RoundedButton("Push Another Screen") {
                        testbed.route(to: \.pushScreen)
                    }

                    RoundedButton("Show Modal") {
                        testbed.route(to: \.modalScreen)
                    }

                    RoundedButton("Dismiss Full Screen") {
                        testbed.dismissCoordinator()
                    }
                }
                .padding(.top, 20)

                Text("Router ID: \(testbed.id)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 40)
            }
            .padding()
        }
    }
}

extension TestbedEnvironmentObjectCoordinator {
    func makePushScreen() -> some View {
        TestbedEnvironmentObjectScreen()
    }

    func makeModalScreen() -> some View {
        NavigationView {
            TestbedEnvironmentObjectScreen()
        }
    }

    func makePushCoordinator() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator(embeddedInStack: false)
    }

    func makeModalCoordinator() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator(embeddedInStack: true)
    }

    func makeFullScreenScreen() -> some View {
        FullScreenTestView()
    }

    func makeFullScreenCoordinator() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator(embeddedInStack: true)
    }

    func makeStart() -> some View {
        TestbedEnvironmentObjectScreen()
    }

    func makeTestbedChild(childId: Int) -> TestbedChildCoordinator {
        return TestbedChildCoordinator(parent: self, childId: childId)
    }
}
