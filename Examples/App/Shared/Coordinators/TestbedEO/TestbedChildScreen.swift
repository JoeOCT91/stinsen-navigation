import Foundation
import Stinsen
import SwiftUI

struct TestbedChildScreen: View {
    let coordinator: TestbedChildCoordinator
    @State private var text: String = ""

    var body: some View {
        GeometryReader { _ in
            ScrollView {
                VStack(spacing: 16) {
                    Text("Child Coordinator Screen")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("This is a ChildCoordinatable that shares the parent's NavigationStack")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    TextField("Test input in child", text: $text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Divider()

                    VStack(spacing: 12) {
                        Text("Child Coordinator Actions")
                            .font(.headline)

                        RoundedButton("Push Another Child") {
                            coordinator.pushAnotherChild()
                        }

                        RoundedButton("Push Regular View") {
                            coordinator.pushView()
                        }

                        RoundedButton("Dismiss This Child") {
                            coordinator.dismissSelf()
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Child Coordinator")
        .navigationBarTitleDisplayMode(.inline)
    }
}
