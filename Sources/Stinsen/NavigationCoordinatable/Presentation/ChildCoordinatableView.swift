import Combine
import Foundation
import SwiftUI

/// A SwiftUI view that renders ChildCoordinatable coordinators within their parent's navigation hierarchy.
///
/// ChildCoordinatableView serves as the presentation layer for ChildCoordinatable coordinators,
/// providing seamless integration with the parent NavigationCoordinatable's navigation system.
/// It respects the child's boundaries while leveraging the parent's navigation infrastructure.
///
/// ## Key Features
/// - **Parent Integration**: Works seamlessly with parent NavigationCoordinatableView
/// - **Boundary Respect**: Only manages navigation within child's scope
/// - **Stack Awareness**: Monitors parent's navigation stack for changes
/// - **Customization**: Applies child coordinator's view customizations
/// - **Memory Management**: Proper cleanup when child is dismissed
///
/// ## Architecture
/// The view coordinates between:
/// - ChildCoordinatableView: Child-specific presentation logic
/// - Parent NavigationCoordinatableView: Main navigation infrastructure
/// - ChildCoordinatable: Child coordinator's navigation logic
/// - Parent NavigationCoordinatable: Parent coordinator's navigation system
///
/// ## Usage
/// This view is typically created automatically by child coordinators and should not be
/// instantiated directly in most cases.
///
/// ```swift
/// // Automatically created by child coordinator
/// childCoordinator.view() // Returns ChildCoordinatableView
/// ```
struct ChildCoordinatableView<T: ChildCoordinatable>: View {
    /// The child coordinator that this view represents
    private let coordinator: T

    /// Unique identifier for this view instance
    private let id: Int

    /// ObservedObject to monitor the child coordinator's changes
    @ObservedObject private var observedCoordinator: T

    /// State to track if the coordinator is active
    @State private var isActive: Bool = true

    /// Cancellables for stack monitoring
    @State private var cancellables = Set<AnyCancellable>()

    /// Initializes a new ChildCoordinatableView for the specified child coordinator.
    ///
    /// Sets up monitoring of the parent's navigation stack and ensures proper
    /// integration with the parent's navigation system.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this view instance
    ///   - coordinator: The child coordinator to create a view for
    ///
    /// ## ID Convention
    /// - `>= 0`: Child view at specific stack position
    /// - Typically matches the child's root position in parent stack
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        _observedCoordinator = ObservedObject(wrappedValue: coordinator)
    }

    /// The main view body that renders the child coordinator's content.
    ///
    /// Integrates with the parent's navigation system while applying
    /// child-specific customizations and boundary enforcement.
    var body: some View {
        childContent
            .onAppear {
                setupStackMonitoring()
            }
            .onDisappear {
                cleanup()
            }
    }

    // MARK: - Private Views

    /// The main child content with customizations applied
    @ViewBuilder
    private var childContent: some View {
        if isActive {
            // Apply child coordinator's customizations to the child content
            coordinator.customize(coordinator.view())
        } else {
            // Coordinator has been dismissed, show empty content
            EmptyView()
        }
    }

    /// Creates the root content for the child coordinator
    private func createRootContent() -> AnyView {
        // The child coordinator's root view should be its main content
        // This is where child-specific UI is rendered
        return AnyView(childCoordinatorContent)
    }

    /// The actual content of the child coordinator
    @ViewBuilder
    private var childCoordinatorContent: some View {
        // Check if we have a valid parent and are within bounds
        if let parent = coordinator.parent,
           let rootIndex = coordinator.rootIndex,
           coordinator.canControl(coordinator.root) {
            // Render content based on current stack state
            VStack {
                // Child coordinator's main content
                renderChildContent()

                // Debug information (remove in production)
                if ProcessInfo.processInfo.environment["DEBUG_CHILD_COORDINATOR"] != nil {
                    debugInfo
                }
            }
        } else {
            // Fallback content when parent relationship is not properly established
            Text("Child Coordinator")
                .foregroundColor(.secondary)
        }
    }

    /// Renders the child coordinator's main content
    @ViewBuilder
    private func renderChildContent() -> some View {
        // This is where child coordinators would render their specific UI
        // For now, we provide a basic implementation that child coordinators can override
        VStack(spacing: 16) {
            Text("Child Coordinator Content")
                .font(.title2)
                .foregroundColor(.primary)

            Text("Stack: \(coordinator.stack.count) items")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Controlled: \(coordinator.controlledStack.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    /// Debug information view
    @ViewBuilder
    private var debugInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("Debug Info")
                .font(.caption.bold())
            Text("ID: \(id)")
                .font(.caption2)
            Text("Root Index: \(coordinator.rootIndex ?? -1)")
                .font(.caption2)
            Text("Parent: \(coordinator.parent != nil ? "Connected" : "Nil")")
                .font(.caption2)
            Text("Active: \(isActive)")
                .font(.caption2)
        }
        .padding(.top, 8)
        .foregroundColor(.secondary)
    }

    // MARK: - Stack Monitoring

    /// Sets up monitoring of the parent's navigation stack
    private func setupStackMonitoring() {
        guard let parent = coordinator.parent else { return }

        // Monitor changes to the parent's navigation stack
        parent.stack.$value
            .sink { [weak coordinator] newStack in
                guard let coordinator = coordinator else { return }
                handleStackChange(newStack, coordinator: coordinator)
            }
            .store(in: &cancellables)
    }

    /// Handles changes to the parent's navigation stack
    private func handleStackChange(_ newStack: [NavigationStackItem], coordinator: T) {
        // Check if our child coordinator is still in the stack
        let isStillActive = newStack.contains { item in
            item.id == coordinator.root.id
        }

        // Update active state if needed
        if isActive != isStillActive {
            DispatchQueue.main.async {
                self.isActive = isStillActive
            }
        }

        // If we're still active, check if we need to respond to stack changes
        if isStillActive {
            handleActiveStackChange(newStack, coordinator: coordinator)
        }
    }

    /// Handles stack changes when the child coordinator is still active
    private func handleActiveStackChange(_ newStack: [NavigationStackItem], coordinator: T) {
        // Child coordinators can override this behavior
        // For now, we just ensure we're respecting boundaries

        // Find our position in the new stack
        guard let rootIndex = newStack.firstIndex(where: { $0.id == coordinator.root.id }) else {
            return
        }

        // Ensure we don't try to control anything beyond our scope
        let controlledItems = Array(newStack[rootIndex...])

        // Update any internal state as needed
        // This is where child-specific stack management would go
    }

    /// Cleanup when the view disappears
    private func cleanup() {
        cancellables.removeAll()
    }
}

// MARK: - Extensions for Child Coordinator Integration

extension ChildCoordinatable {
    /// Creates a ChildCoordinatableView for this coordinator
    /// Override the default view() implementation to return this specialized view
    func childView() -> some View {
        // Use the root's keyPath hash as the ID for consistency
        let viewId = root.keyPath
        return ChildCoordinatableView(id: viewId, coordinator: self)
    }
}

// MARK: - Helper Views

/// A view that can be used as a placeholder for child coordinator content
struct ChildCoordinatorPlaceholder: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.stack")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Preview Support

#if DEBUG
    struct ChildCoordinatableView_Previews: PreviewProvider {
        static var previews: some View {
            ChildCoordinatorPlaceholder(
                "Child Coordinator",
                subtitle: "This is where child coordinator content would appear"
            )
        }
    }
#endif
