import Combine
import Foundation
import SwiftUI

/// A SwiftUI view that renders NavigationCoordinatable coordinators using modern NavigationStack.
///
/// NavigationCoordinatableView serves as the presentation layer for NavigationCoordinatable coordinators,
/// providing a clean interface between the coordinator pattern and SwiftUI's navigation system.
/// It supports iOS 16+ NavigationStack with comprehensive presentation type handling.
///
/// ## Key Features
/// - **Push Navigation**: Uses SwiftUI NavigationStack for hierarchical navigation
/// - **Modal Presentations**: Handles .sheet() presentations for modal content
/// - **Full-Screen Presentations**: Supports .fullScreenCover() on iOS for immersive content
/// - **Dismissal Management**: Automatically handles dismissal actions and stack synchronization
/// - **Cross-Platform**: Gracefully handles platform-specific features
///
/// ## Architecture
/// The view delegates all navigation state management to PresentationHelper, maintaining
/// a clean separation of concerns:
/// - NavigationCoordinatableView: Pure presentation layer
/// - PresentationHelper: Navigation state management and logic
/// - NavigationStack: Coordinator's navigation data model
///
/// ## Usage
/// This view is typically created automatically by coordinators and should not be
/// instantiated directly in most cases.
///
/// ```swift
/// // Automatically created by coordinator
/// coordinator.view() // Returns NavigationCoordinatableView
/// ```
struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    /// Manages all navigation presentation state and logic
    @StateObject private var presentationHelper: PresentationHelper<T>

    /// The coordinator that this view represents
    @ObservedObject private var coordinator: T

    /// Unique identifier for this view instance
    private let id: Int

    /// Router instance for navigation operations
    private let router: NavigationRouter<T>

    /// The current navigation stack from the coordinator
    private var stack: NavigationStack<T> {
        coordinator.stack
    }

    /// The current root observer from the stack
    private var rootObserver: NavigationRoot {
        // Ensure root is set up before accessing
        stack.ensureRoot(with: coordinator)
        let root = stack.root
        print("🔍 Root observer for \(type(of: coordinator)) (id: \(id)): \(type(of: root.item.child))")
        return root
    }

    /// State to force view updates when coordinator stack changes
    @State private var stackChangeId = UUID()

    /// Computed binding for coordinator presentation
    private var coordinatorBinding: Binding<Bool> {
        Binding(
            get: { presentationHelper.pushedCoordinator != nil },
            set: { if !$0 { presentationHelper.pushedCoordinator = nil } }
        )
    }

    /// Initializes a new NavigationCoordinatableView for the specified coordinator.
    ///
    /// Sets up the presentation helper, router, and ensures the navigation stack
    /// has a proper root configuration. The router is automatically stored in
    /// the global RouterStore for access by child views.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this view instance (-1 for main coordinator root)
    ///   - coordinator: The coordinator to create a view for
    ///
    /// ## ID Convention
    /// - `-1`: Main coordinator root view
    /// - `>= 0`: Child view content at specific stack index
    init(id: Int, coordinator: T) {
        self.id = id
        _coordinator = ObservedObject(wrappedValue: coordinator)

        router = NavigationRouter(
            id: id,
            coordinator: coordinator.routerStorable
        )

        // Initialize StateObject
        _presentationHelper = StateObject(
            wrappedValue: PresentationHelper(id: id, coordinator: coordinator)
        )

        // Ensure root is set up for current stack
        coordinator.stack.ensureRoot(with: coordinator)

        RouterStore.shared.store(router: router)
    }

    /// The main view body that renders the navigation hierarchy.
    ///
    /// Uses modern SwiftUI NavigationStack for push navigation and handles
    /// modal and full-screen presentations through the PresentationHelper.
    var body: some View {
        coordinatorNavigationDestination(
            SwiftUI.NavigationStack(path: $presentationHelper.pushPath) {
                rootContent
                    .navigationDestination(for: NavigationStackItem.self) { item in
                        presentationHelper.createDestinationContent(for: item)
                            .environmentObject(router)
                    }
            }
        )
        .environmentObject(router)
    }

    // MARK: - Content Views

    /// Determines the appropriate root content based on the view's role.
    ///
    /// Renders different content depending on whether this is the main coordinator
    /// root view (id == -1) or a child view at a specific stack index.
    ///
    /// ## Content Types
    /// - **Main Root** (id == -1): Coordinator's customized root view
    /// - **Child View** (id >= 0): Current view content at stack index
    @ViewBuilder
    private var rootContent: some View {
        if id == -1 {
            // Main coordinator root view
            coordinator.customize(
                AnyView(rootObserver.item.child.view())
            )
            .onAppear {
                print("🏠 Rendering main root for coordinator: \(type(of: coordinator))")
                print("🎯 Root child view type: \(type(of: rootObserver.item.child.view()))")
            }
        } else {
            // This shouldn't happen in normal navigation flow
            Text("Unexpected root content for id: \(id)")
                .onAppear {
                    print("⚠️ Unexpected root content request for id: \(id)")
                }
        }
    }
}

// MARK: - Version-Specific Extensions

extension NavigationCoordinatableView {
    /// Applies coordinator navigation destination with version-specific implementation
    @ViewBuilder
    private func coordinatorNavigationDestination<Content: View>(_ content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            // Use the cleaner item-based API on newer versions
            content.navigationDestination(item: $presentationHelper.pushedCoordinator) { coordinatorItem in
                presentationHelper.createCoordinatorContent(for: coordinatorItem)
                    .environmentObject(router)
            }
        } else {
            // Fall back to isPresented API on older versions
            content.navigationDestination(isPresented: coordinatorBinding) {
                if let coordinatorItem = presentationHelper.pushedCoordinator {
                    presentationHelper.createCoordinatorContent(for: coordinatorItem)
                        .environmentObject(router)
                }
            }
        }
    }
}
