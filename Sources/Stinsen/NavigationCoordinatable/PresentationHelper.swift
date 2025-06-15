import Combine
import Foundation
import SwiftUI

/// A helper class that manages presentation state for NavigationCoordinatable coordinators.
///
/// PresentationHelper encapsulates all navigation state management logic, including:
/// - Push navigation path management for SwiftUI NavigationStack
/// - Modal presentation state using .sheet()
/// - Full-screen presentation state using .fullScreenCover() (iOS only)
/// - Pop detection and dismissal action execution
/// - Two-way synchronization between UI state and coordinator stack
///
/// This class acts as a bridge between the coordinator's navigation stack and SwiftUI's
/// presentation mechanisms, ensuring proper state synchronization and dismissal handling.
///
/// ## Architecture
/// The PresentationHelper observes changes to the coordinator's stack and filters items
/// by presentation type:
/// - Push items → NavigationStack path
/// - Modal items → .sheet() presentation
/// - Full-screen items → .fullScreenCover() presentation
///
/// It also monitors NavigationStack path changes to detect when users navigate back
/// using system gestures or back buttons, ensuring dismissal actions are called appropriately.
final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    // MARK: - Properties

    /// The unique identifier for this presentation helper instance
    private let id: Int

    /// The coordinator that this helper manages presentation for
    private let coordinator: T

    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Previous push path state used for pop detection
    private var previousPushPath: [NavigationStackItem] = []

    /// The current navigation path for push presentations.
    ///
    /// This array contains only items with `.push` presentation type and is directly
    /// bound to SwiftUI's NavigationStack path. Changes to this array trigger
    /// navigation updates and pop detection logic.
    @Published var pushPath: [NavigationStackItem] = []

    /// The current modal presentation item.
    ///
    /// When not nil, triggers a .sheet() presentation. Only one modal can be
    /// presented at a time. Setting to nil dismisses the current modal.
    @Published var modalItem: IdentifiableWrapper?

    /// The current full-screen presentation item (iOS only).
    ///
    /// When not nil, triggers a .fullScreenCover() presentation. Only one full-screen
    /// presentation can be active at a time. Setting to nil dismisses the current presentation.
    @Published var fullScreenItem: IdentifiableWrapper?

    // MARK: - Initialization

    /// Initializes a new PresentationHelper for the specified coordinator.
    ///
    /// Sets up observation of stack changes and push path changes, then performs
    /// an initial update of presentation states.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this helper instance
    ///   - coordinator: The coordinator to manage presentation for
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator

        observeStackChanges()
        observePushPathChanges()
        updatePresentationStates()
    }

    /// Sets up observation of the coordinator's stack value changes.
    ///
    /// Subscribes to the coordinator's stack `$value` publisher and updates
    /// presentation states whenever the stack changes. Updates are dispatched
    /// to the main queue to ensure UI consistency.
    private func observeStackChanges() {
        coordinator.stack.$value
            .sink { [weak self] stackValue in
                DispatchQueue.main.async {
                    self?.updatePresentationStates(from: stackValue)
                }
            }
            .store(in: &cancellables)
    }

    /// Sets up observation of push path changes for pop detection.
    ///
    /// Monitors changes to the `pushPath` array (excluding the initial value)
    /// to detect when users navigate back using system controls. This enables
    /// proper dismissal action execution and stack synchronization.
    private func observePushPathChanges() {
        $pushPath
            .dropFirst()
            .sink { [weak self] newPushPath in
                self?.handlePushPathChange(newPushPath)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Updates all presentation states based on the current or provided stack value.
    ///
    /// Filters the stack items by presentation type and updates the corresponding
    /// published properties. This method ensures that the UI presentation state
    /// stays synchronized with the coordinator's navigation stack.
    ///
    /// - Parameter stackValue: Optional stack value to use instead of current coordinator stack
    ///
    /// ## Filtering Logic
    /// - Push items: Added to `pushPath` for NavigationStack
    /// - Modal items: Last modal item set as `modalItem` for .sheet()
    /// - Full-screen items: Last full-screen item set as `fullScreenItem` for .fullScreenCover()
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

    /// Handles changes to the push path to detect popped items and execute dismissal actions.
    ///
    /// Compares the new push path with the previous path to identify items that were
    /// removed (popped). For each popped item, executes its dismissal action if one exists,
    /// then synchronizes the coordinator's stack with the new path state.
    ///
    /// - Parameter newPushPath: The updated push path from NavigationStack
    ///
    /// ## Pop Detection Logic
    /// 1. Identifies items present in previous path but not in new path
    /// 2. Executes dismissal actions for popped items
    /// 3. Updates coordinator stack to match new push path
    /// 4. Sends poppedTo notification for coordinator awareness
    /// 5. Updates previous path for next comparison
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

    /// Handles dismissal of modal presentations.
    ///
    /// Called when a modal sheet is dismissed by user interaction (swipe down, tap outside, etc.).
    /// Executes the dismissal action if one exists, removes the modal item from the coordinator's
    /// stack, and resets the modal presentation state.
    ///
    /// ## Dismissal Process
    /// 1. Resets `modalItem` to nil immediately to prevent race conditions
    /// 2. Executes dismissal action if registered
    /// 3. Removes dismissed item from coordinator stack
    func handleModalDismissal() {
        guard let dismissedItem = modalItem else { return }

        // Reset the modal item immediately to prevent race conditions
        modalItem = nil

        // Call dismissal action if exists
        if let dismissalAction = coordinator.stack.dismissalAction[dismissedItem.item.keyPath] {
            dismissalAction()
        }

        // Remove the dismissed modal item from the stack
        coordinator.stack.value.removeAll {
            $0.id == dismissedItem.id && $0.presentationType.isModal
        }
    }

    #if os(iOS)
        /// Handles dismissal of full-screen presentations (iOS only).
        ///
        /// Called when a full-screen cover is dismissed by user interaction.
        /// Executes the dismissal action if one exists, removes the full-screen item from
        /// the coordinator's stack, and resets the full-screen presentation state.
        ///
        /// ## Dismissal Process
        /// 1. Resets `fullScreenItem` to nil immediately to prevent race conditions
        /// 2. Executes dismissal action if registered
        /// 3. Removes dismissed item from coordinator stack
        func handleFullScreenDismissal() {
            guard let dismissedItem = fullScreenItem else { return }

            // Reset the fullscreen item immediately to prevent race conditions
            fullScreenItem = nil

            // Call dismissal action if exists
            if let dismissalAction = coordinator.stack.dismissalAction[dismissedItem.item.keyPath] {
                dismissalAction()
            }

            // Remove the dismissed fullscreen item from the stack
            coordinator.stack.value.removeAll {
                $0.id == dismissedItem.id && $0.presentationType.isFullScreen
            }
        }
    #endif

    /// Creates the destination content view for a navigation stack item.
    ///
    /// Extracts the presentable from the navigation stack item and returns its view
    /// wrapped in AnyView for type erasure. This method is used by NavigationStack's
    /// navigationDestination modifier and sheet/fullScreenCover presentations.
    ///
    /// - Parameter item: The navigation stack item to create content for
    /// - Returns: AnyView containing the item's presentable view
    func createDestinationContent(for item: NavigationStackItem) -> AnyView {
        return AnyView(item.presentable.view())
    }
}

// MARK: - Helper Types

/// Wrapper to make NavigationStackItem work with sheet/fullScreenCover presentations.
///
/// SwiftUI's .sheet() and .fullScreenCover() modifiers require Identifiable items.
/// This wrapper provides the necessary Identifiable conformance while maintaining
/// access to the underlying NavigationStackItem.
///
/// The wrapper uses the NavigationStackItem's id property to satisfy Identifiable,
/// ensuring proper presentation and dismissal behavior.
struct IdentifiableWrapper: Identifiable {
    /// The wrapped navigation stack item
    let item: NavigationStackItem

    /// Identifiable conformance using the wrapped item's id
    var id: Int { item.id }

    /// Creates a new wrapper around the specified navigation stack item.
    ///
    /// - Parameter item: The NavigationStackItem to wrap
    init(_ item: NavigationStackItem) {
        self.item = item
    }
}
