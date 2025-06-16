import Foundation
import Stinsen
import SwiftUI

struct TestbedChildScreen: View {
    let coordinator: TestbedChildCoordinator
    @State private var text: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.gradient)

                    Text("Child Coordinator")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("Shares NavigationStack with Parent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                // Info Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("About ChildCoordinatable")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Text(
                        """
                        This coordinator demonstrates the ChildCoordinatable protocol.
                        It shares the parent's NavigationStack, allowing multiple coordinators to coexist without nesting conflicts.
                        """
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Input")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    TextField("Enter some text...", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Actions Section
                VStack(spacing: 16) {
                    Text("Navigation Actions")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        ActionButton(
                            title: "Push Another Child",
                            subtitle: "Add another ChildCoordinatable",
                            icon: "plus.circle.fill",
                            color: .green
                        ) {
                            coordinator.pushAnotherChild()
                        }

                        ActionButton(
                            title: "Push Regular View",
                            subtitle: "Navigate to a standard view",
                            icon: "doc.fill",
                            color: .blue
                        ) {
                            coordinator.pushView()
                        }

                        ActionButton(
                            title: "Dismiss This Child",
                            subtitle: "Remove from navigation stack",
                            icon: "xmark.circle.fill",
                            color: .red
                        ) {
                            coordinator.dismissSelf()
                        }
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Child Coordinator")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ActionButton Component

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
