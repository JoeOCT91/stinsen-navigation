import Combine
import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    @StateObject private var presentationHelper: PresentationHelper<T>
    @ObservedObject var stack: NavigationStack<T>
    let coordinator: T

    private let id: Int
    private let router: NavigationRouter<T>

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
        RouterStore.shared.store(router: router)
    }

    var body: some View {
        SwiftUI.NavigationStack(path: $presentationHelper.pushPath) {
            rootContent
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

    @ViewBuilder
    private var rootContent: some View {
        if id == -1 {
            // Main coordinator root view
            coordinator.customize(
                AnyView(stack.root.item.child.view())
            )
        } else {
            // Child view content
            currentViewContent
        }
    }

    @ViewBuilder
    private var currentViewContent: some View {
        if let item = stack.value[safe: id] {
            AnyView(item.presentable.view())
        }
    }
}
