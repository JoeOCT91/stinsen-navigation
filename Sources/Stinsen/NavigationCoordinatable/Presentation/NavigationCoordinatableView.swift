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

    /// Computed binding for coordinator presentation
    ///
    /// This binding is the source of truth for coordinator dismissals.
    /// When SwiftUI dismisses a coordinator (via swipe back, navigation, etc.),
    /// the setter is called with false, which triggers the coordinator stack update.
    private var coordinatorBinding: Binding<Bool> {
        Binding(
            get: { presentationHelper.pushedCoordinator != nil },
            set: { isPresented in
                if !isPresented {
                    // SwiftUI dismissed the coordinator - delegate to presentation helper
                    presentationHelper.handleCoordinatorDismissal()
                }
            }
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

        RouterStore.shared.store(router: router)
    }

    /// The main view body that renders the navigation hierarchy.
    ///
    /// Uses modern SwiftUI NavigationStack for push navigation and handles
    /// modal and full-screen presentations through the PresentationHelper.
    var body: some View {
        contentView
            .environmentObject(router)
            .onReceive(presentationHelper.$pushPath) { newPath in
                presentationHelper.handlePushPathChange(newPath)
            }
            .onReceive(presentationHelper.$rootChangeId) { _ in
                print("🔄 NavigationCoordinatableView: Root change detected, forcing view update")
            }
            // Handle modal presentations
            .sheet(item: $presentationHelper.modalItem) { modalItem in
                createPresentationContent(for: modalItem)
                    .environmentObject(router)
            }
            // Handle full-screen presentations (iOS only, falls back to sheet on other platforms)
            .fullScreenCoverIfAvailable(item: $presentationHelper.fullScreenItem) { fullScreenItem in
                createPresentationContent(for: fullScreenItem)
                    .environmentObject(router)
            }
    }

    // MARK: - Private Views

    /// The main content view that conditionally wraps content in NavigationStack
    @ViewBuilder
    private var contentView: some View {
        if coordinator.embeddedInStack {
            SwiftUI.NavigationStack(path: $presentationHelper.pushPath) {
                navigationStackContent
            }
        } else {
            rootContent
        }
    }

    /// Navigation stack content with destination handlers
    @ViewBuilder
    private var navigationStackContent: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            modernNavigationDestinations
        } else {
            legacyNavigationDestinations
        }
    }

    /// Modern navigation destinations using item-based API (iOS 17+)
    @ViewBuilder
    @available(iOS 17.0, macOS 14.0, *)
    private var modernNavigationDestinations: some View {
        rootContent
            .navigationDestination(for: NavigationStackItem.self) { item in
                createDestinationView(for: item)
            }
            .navigationDestination(item: $presentationHelper.pushedCoordinator) { coordinatorItem in
                createCoordinatorView(for: coordinatorItem)
            }
    }

    /// Legacy navigation destinations using isPresented API (iOS 16)
    @ViewBuilder
    private var legacyNavigationDestinations: some View {
        rootContent
            .navigationDestination(for: NavigationStackItem.self) { item in
                createDestinationView(for: item)
            }
            .navigationDestination(isPresented: coordinatorBinding) {
                if let coordinatorItem = presentationHelper.pushedCoordinator {
                    createCoordinatorView(for: coordinatorItem)
                }
            }
    }

    // MARK: - Platform-Specific Extensions

    private extension View {
        /// Applies full-screen cover on iOS, sheet on other platforms
        @ViewBuilder
        func fullScreenCoverIfAvailable<Item: Identifiable, Content: View>(
            item: Binding<Item?>,
            content: @escaping (Item) -> Content
        ) -> some View {
            #if os(iOS)
                fullScreenCover(item: item, content: content)
            #else
                sheet(item: item, content: content)
            #endif
        }
    }

    /// Creates a destination view for a navigation stack item
    @ViewBuilder
    private func createDestinationView(for item: NavigationStackItem) -> some View {
        presentationHelper.createDestinationContent(for: item)
            .environmentObject(router)
    }

    /// Creates a coordinator view for a pushed coordinator
    @ViewBuilder
    private func createCoordinatorView(for coordinatorItem: NavigationStackItem) -> some View {
        presentationHelper.createCoordinatorContent(for: coordinatorItem)
            .environmentObject(router)
    }

    /// Creates content for modal and full-screen presentations
    @ViewBuilder
    private func createPresentationContent(for item: NavigationStackItem) -> some View {
        // Check if this is a coordinator or a regular view
        if item.presentable is any Coordinatable {
            presentationHelper.createCoordinatorContent(for: item)
                .environmentObject(router)
        } else {
            presentationHelper.createDestinationContent(for: item)
                .environmentObject(router)
        }
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
            // Ensure root is available before rendering
            let rootItem = coordinator.stack.safeRoot(with: coordinator).item
            coordinator.customize(
                AnyView(rootItem.child.view())
            )
        }
    }
}
