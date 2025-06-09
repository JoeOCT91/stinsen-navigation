import Foundation
import SwiftUI
import Combine

/// A SwiftUI view that provides navigation functionality for coordinators
///
/// This view:
/// - Uses SwiftUI's NavigationStack for push navigation
/// - Handles sheets and full screen covers separately
/// - Maintains compatibility with the existing coordinator architecture
/// - Eliminates the need for PresentationHelper
struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {

    // MARK: - Properties

    /// The coordinator managing navigation logic
    let coordinator: T

    /// Direct reference to the coordinator's navigation stack for observation
    @ObservedObject private var stack: NavigationStack<T>

    /// Router for handling navigation events
    @StateObject private var router: NavigationRouter<T>

    // MARK: - Initialization

    /// Creates a new navigation view for the given coordinator
    /// - Parameter coordinator: The coordinator to use for navigation
    init(coordinator: T) {
        self.coordinator = coordinator
        self.stack = coordinator.stack

        // Initialize router with root ID (-1)
        self._router = StateObject(
            wrappedValue: NavigationRouter(id: -1, coordinator: coordinator.routerStorable)
        )

        // Setup root if needed
        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }
    }

    var body: some View {
        SwiftUI.NavigationStack(path: $stack.navigationPath) {
            rootView
                .navigationDestination(for: NavigationStackItem.self) { item in
                    destinationView(for: item)
                        .environmentObject(router)
                }
        }
        .sheet(item: $stack.sheetItem, onDismiss: {
            handleDismissal(for: stack.sheetItem)
        }) { item in
            // Sheets get their own NavigationStack
            SwiftUI.NavigationStack {
                destinationView(for: item)
                    .environmentObject(router)
            }
        }
        .fullScreenCover(item: $stack.fullScreenCoverItem, onDismiss: {
            handleDismissal(for: stack.fullScreenCoverItem)
        }) { item in
            // Full screen covers get their own NavigationStack
            SwiftUI.NavigationStack {
                destinationView(for: item)
                    .environmentObject(router)
            }
        }
        .environmentObject(router)
    }

    /// The root view of the navigation hierarchy
    @ViewBuilder
    private var rootView: some View {
        if let root = stack.root {
            coordinator.customize(AnyView(root.item.child.view()))
        }
    }

    /// Creates the appropriate view for a navigation item
    /// - Parameter item: The navigation stack item to display
    /// - Returns: The view to display
    @ViewBuilder
    private func destinationView(for item: NavigationStackItem) -> some View {
        Group {
            if let view = item.presentable as? AnyView {
                view
            } else {
                AnyView(item.presentable.view())
            }
        }
        .onDisappear {
            handleDismissal(for: item)
        }
    }

    // MARK: - Helper Methods

    /// Handles cleanup when a view is dismissed
    /// - Parameter item: The item being dismissed
    private func handleDismissal(for item: NavigationStackItem?) {
        guard let item = item else { return }

        // Execute any dismissal action
        stack.dismissalAction[item.keyPath]?()
        // Clean up the action
        stack.dismissalAction[item.keyPath] = nil
    }
}
