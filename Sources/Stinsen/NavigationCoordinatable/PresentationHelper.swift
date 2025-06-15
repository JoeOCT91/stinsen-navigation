import Combine
import Foundation
import SwiftUI

final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    // MARK: - Properties
    private let id: Int
    private let coordinator: T
    private var cancellables = Set<AnyCancellable>()

    private var previousPushPath: [NavigationStackItem] = []

    @Published var pushPath: [NavigationStackItem] = []
    @Published var modalItem: IdentifiableWrapper?
    @Published var fullScreenItem: IdentifiableWrapper?

    // MARK: - Initialization
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator

        observeStackChanges()
        observePushPathChanges()
        updatePresentationStates()
    }

    private func observeStackChanges() {
        coordinator.stack.$value
            .sink { [weak self] stackValue in
                DispatchQueue.main.async {
                    self?.updatePresentationStates(from: stackValue)
                }
            }
            .store(in: &cancellables)
    }

    private func observePushPathChanges() {
        $pushPath
            .dropFirst()  // Skip initial value
            .sink { [weak self] newPushPath in
                self?.handlePushPathChange(newPushPath)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func updatePresentationStates(from stackValue: [NavigationStackItem]? = nil) {
        let stack = stackValue ?? coordinator.stack.value

        // Update push path
        let newPushItems = stack.filter { $0.presentationType.isPush }
        if pushPath != newPushItems {
            previousPushPath = pushPath
            pushPath = newPushItems
        }

        // Update modal item
        let currentModal = stack.last { $0.presentationType.isModal }
        let newModalItem = currentModal.map { IdentifiableWrapper($0) }
        if modalItem?.id != newModalItem?.id {
            modalItem = newModalItem
        }

        #if os(iOS)
            // Update fullscreen item (iOS only)
            let currentFullScreen = stack.last { $0.presentationType.isFullScreen }
            let newFullScreenItem = currentFullScreen.map { IdentifiableWrapper($0) }
            if fullScreenItem?.id != newFullScreenItem?.id {
                fullScreenItem = newFullScreenItem
            }
        #endif
    }

    private func handlePushPathChange(_ newPushPath: [NavigationStackItem]) {
        // Find items that were popped (in previous but not in new)
        let poppedItems = previousPushPath.filter { previousItem in
            !newPushPath.contains { $0.id == previousItem.id }
        }

        // Call dismissal actions for popped items
        for poppedItem in poppedItems {
            if let dismissalAction = coordinator.stack.dismissalAction[poppedItem.keyPath] {
                dismissalAction()
            }
        }

        // Update the coordinator's stack to match the new push path
        // Keep non-push items and replace push items with the new path
        let nonPushItems = coordinator.stack.value.filter { !$0.presentationType.isPush }
        coordinator.stack.value = nonPushItems + newPushPath

        // Notify about the pop if items were removed
        if !poppedItems.isEmpty, let lastRemainingItem = newPushPath.last {
            coordinator.stack.poppedTo.send(lastRemainingItem.keyPath)
        } else if newPushPath.isEmpty {
            // Popped to root
            coordinator.stack.poppedTo.send(-1)
        }

        // Update previous path for next comparison
        previousPushPath = newPushPath
    }

    func handleModalDismissal() {
        guard let dismissedItem = modalItem else { return }

        // Call dismissal action if exists
        if let dismissalAction = coordinator.stack.dismissalAction[dismissedItem.item.keyPath] {
            dismissalAction()
        }

        // Remove the dismissed modal item from the stack
        coordinator.stack.value.removeAll {
            $0.id == dismissedItem.id && $0.presentationType.isModal
        }

        // Reset the modal item
        modalItem = nil
    }

    #if os(iOS)
        func handleFullScreenDismissal() {
            guard let dismissedItem = fullScreenItem else { return }

            // Call dismissal action if exists
            if let dismissalAction = coordinator.stack.dismissalAction[dismissedItem.item.keyPath] {
                dismissalAction()
            }

            // Remove the dismissed fullscreen item from the stack
            coordinator.stack.value.removeAll {
                $0.id == dismissedItem.id && $0.presentationType.isFullScreen
            }

            // Reset the fullscreen item
            fullScreenItem = nil
        }
    #endif

    func createDestinationContent(for item: NavigationStackItem) -> AnyView {
        return AnyView(item.presentable.view())
    }
}

// MARK: - Helper Types

/// Wrapper to make NavigationStackItem work with sheet/fullScreenCover
struct IdentifiableWrapper: Identifiable {
    let item: NavigationStackItem
    var id: Int { item.id }

    init(_ item: NavigationStackItem) {
        self.item = item
    }
}
