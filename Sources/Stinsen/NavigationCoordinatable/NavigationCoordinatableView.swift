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

    /// Observes the root navigation item for changes
    @ObservedObject private var rootObserver: NavigationRoot

    /// The coordinator's navigation stack
    let stack: NavigationStack<T>

    /// The coordinator that this view represents
    let coordinator: T

    /// Unique identifier for this view instance
    private let id: Int

    /// Router instance for navigation operations
    private let router: NavigationRouter<T>

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
        self.coordinator = coordinator
        self.stack = coordinator.stack

        self.router = NavigationRouter(
            id: id,
            coordinator: coordinator.routerStorable
        )

        // Initialize StateObject
        self._presentationHelper = StateObject(
            wrappedValue: PresentationHelper(id: id, coordinator: coordinator))

        // Ensure root is set up
        stack.ensureRoot(with: coordinator)

        // Initialize root observer
        self.rootObserver = stack.root

        RouterStore.shared.store(router: router)
    }

    /// The main view body that renders the navigation hierarchy.
    ///
    /// Creates a SwiftUI NavigationStack bound to the presentation helper's push path,
    /// with support for modal and full-screen presentations. All presentation types
    /// are handled with proper dismissal action execution.
    ///
    /// ## Navigation Structure
    /// ```
    /// NavigationStack (push items)
    /// ├── Root Content
    /// ├── .navigationDestination (for push navigation)
    /// ├── .sheet (for modal presentations)
    /// └── .fullScreenCover (for full-screen presentations, iOS only)
    /// ```
    var body: some View {
        SwiftUI.NavigationStack(path: $presentationHelper.pushPath) {
            rootContent
                #if os(iOS)
                    .toolbar(.visible, for: .navigationBar)
                #endif
                .navigationDestination(for: NavigationStackItem.self) { item in
                    presentationHelper.createDestinationContent(for: item)
                        .environmentObject(router)
                }
        }
        .sheet(
            item: $presentationHelper.modalItem,
            onDismiss: {
                presentationHelper.handleModalDismissal()
            }
        ) { wrapper in
            presentationHelper.createDestinationContent(for: wrapper.item)
                .environmentObject(router)
        }
        #if os(iOS)
            .fullScreenCover(
                item: $presentationHelper.fullScreenItem,
                onDismiss: {
                    presentationHelper.handleFullScreenDismissal()
                }
            ) { wrapper in
                presentationHelper.createDestinationContent(for: wrapper.item)
                .environmentObject(router)
            }
        #endif
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
        } else {
            // Child view content
            currentViewContent
        }
    }

    /// Renders the current view content for child views.
    ///
    /// Safely accesses the navigation stack at the specified index and renders
    /// the corresponding presentable view. Returns empty view if index is out of bounds.
    ///
    /// ## Safety
    /// Uses safe array access to prevent crashes when the stack changes during
    /// view updates or when the index becomes invalid.
    @ViewBuilder
    private var currentViewContent: some View {
        if let item = stack.value[safe: id] {
            AnyView(item.presentable.view())
        }
    }
}
