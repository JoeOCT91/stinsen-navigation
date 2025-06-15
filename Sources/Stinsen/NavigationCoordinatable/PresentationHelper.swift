import Combine
import Foundation
import SwiftUI

/// A helper class that manages presentation state for NavigationCoordinatable coordinators.
///
/// PresentationHelper handles the presentation logic for navigation items, including
/// modal presentations, full-screen presentations, and push navigation. It observes
/// the coordinator's navigation stack and updates presentation state accordingly.
public final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    @ObservedObject private var coordinator: T
    private var cancellables = Set<AnyCancellable>()

    /// Push navigation path for SwiftUI NavigationStack (regular views only)
    @Published var pushPath: [NavigationStackItem] = []

    /// Coordinator push navigation (separate from regular push navigation)
    @Published var pushedCoordinator: NavigationStackItem?

    /// Modal presentation item
    @Published var modalItem: NavigationStackItem?

    /// Full-screen presentation item
    @Published var fullScreenItem: NavigationStackItem?

    /// The current navigation stack from the coordinator
    private var navigationStack: NavigationStack<T> {
        coordinator.stack
    }

    /// Keep track of the current stack to detect changes
    private var currentStackId: ObjectIdentifier?

    /// Flag to prevent circular updates during dismissal handling
    private var isDismissalInProgress = false

    // MARK: - Initialization

    /// Initializes a new PresentationHelper for the specified coordinator.
    ///
    /// Sets up observation of stack changes and push path changes, then performs
    /// an initial update of presentation states.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this helper instance
    ///   - coordinator: The coordinator to manage presentation for
    public init(id: Int, coordinator: T) {
        self.id = id
        _coordinator = ObservedObject(wrappedValue: coordinator)

        // Initialize current stack tracking
        currentStackId = ObjectIdentifier(coordinator.stack)

        observeCurrentStack()
    }

    func updatePresentationStates() {
        // Skip update if dismissal is in progress to prevent circular updates
        guard !isDismissalInProgress else { return }

        let currentStack = navigationStack
        let stackItems = currentStack.value

        // Get all push items
        let allPushItems = stackItems.filter { $0.presentationType == .push }

        // Separate regular views from coordinators
        let regularItems = allPushItems.filter { !($0.presentable is any Coordinatable) }
        let coordinatorItems = allPushItems.filter { $0.presentable is any Coordinatable }

        // Find the last (top-most) coordinator in the push stack
        let lastCoordinator = coordinatorItems.last

        if let lastCoordinatorItem = lastCoordinator {
            // There's a coordinator in the push stack
            // Find regular items that come BEFORE the last coordinator
            let lastCoordinatorIndex = stackItems.firstIndex(where: { $0.id == lastCoordinatorItem.id }) ?? 0
            let regularItemsBeforeCoordinator = regularItems.filter { regularItem in
                if let regularIndex = stackItems.firstIndex(where: { $0.id == regularItem.id }) {
                    return regularIndex < lastCoordinatorIndex
                }
                return false
            }

            // Update state: coordinator is active, regular path contains only items before coordinator
            if pushedCoordinator?.id != lastCoordinatorItem.id {
                pushedCoordinator = lastCoordinatorItem
                print("🎯 PresentationHelper: Set pushed coordinator to \(type(of: lastCoordinatorItem.presentable))")
            }
            if pushPath != regularItemsBeforeCoordinator {
                pushPath = regularItemsBeforeCoordinator
                print("🛤️ PresentationHelper: Updated pushPath to \(regularItemsBeforeCoordinator.count) items (before coordinator)")
            }
        } else {
            // No coordinator in push stack, show all regular items
            if pushPath != regularItems {
                pushPath = regularItems
                print("🛤️ PresentationHelper: Updated pushPath to \(regularItems.count) regular items (no coordinator)")
            }
            if pushedCoordinator != nil {
                pushedCoordinator = nil
                print("🎯 PresentationHelper: Cleared pushed coordinator")
            }
        }
    }

    private func observeCurrentStack() {
        // ONLY observe coordinator stack changes - don't observe our own published properties
        // This prevents circular updates and makes the data flow unidirectional:
        // Coordinator Stack -> PresentationHelper -> SwiftUI Navigation
        navigationStack.$value.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updatePresentationStates()
            }
        }
        .store(in: &cancellables)
//
//        navigationStack.poppedTo.sink { <#Int#> in
//            <#code#>
//        }
    }

    /// Creates the destination content view for regular navigation stack items (non-coordinators).
    func createDestinationContent(for item: NavigationStackItem) -> some View {
        return item.presentableWrapper.createView()
    }

    /// Creates the coordinator content view, avoiding nested NavigationStack.
    func createCoordinatorContent(for item: NavigationStackItem) -> AnyView {
        // For coordinators, get their root content directly to avoid nested NavigationStack
        if let coordinator = item.presentable as? any Coordinatable {
            return AnyView(coordinator.view())
        } else {
            // Fallback
            return item.presentableWrapper.createView()
        }
    }

    // MARK: - Dismissal Handling

    /// Handles coordinator dismissal initiated by SwiftUI navigation.
    ///
    /// This method should be called when SwiftUI dismisses a coordinator (via swipe back,
    /// navigation button, etc.). It's responsible for:
    /// 1. Finding the dismissed coordinator in the stack
    /// 2. Triggering its dismissal action if present
    /// 3. Updating the coordinator stack to match SwiftUI's navigation state
    /// 4. Properly restoring the path state after coordinator dismissal
    public func handleCoordinatorDismissal() {
        // Set flag to prevent circular updates
        isDismissalInProgress = true

        // Use a separate queue to avoid deadlock with the main observation
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            defer { self.isDismissalInProgress = false }

            let currentStack = self.navigationStack
            let stackItems = currentStack.value

            // Find the last coordinator in the stack (the one being dismissed)
            if let lastCoordinatorIndex = stackItems.lastIndex(where: { $0.presentable is any Coordinatable }) {
                // Trigger dismissal action for the coordinator if it exists
                if let dismissalAction = currentStack.dismissalAction[lastCoordinatorIndex] {
                    dismissalAction()
                }

                // Pop the coordinator from the stack
                self.coordinator.popTo(lastCoordinatorIndex - 1, nil)
                print("📤 PresentationHelper: Popped coordinator from stack to index \(lastCoordinatorIndex - 1)")

                // After popping, update presentation states to properly restore paths
                // This will be handled by the stack observation, but we clear coordinator reference here
                self.pushedCoordinator = nil
                print("🎯 PresentationHelper: Cleared coordinator after dismissal")
            }
        }
    }

    /// Handles regular view dismissal initiated by SwiftUI navigation.
    ///
    /// This method should be called when the push path changes, indicating that SwiftUI
    /// has dismissed one or more regular views (non-coordinators). It's responsible for:
    /// 1. Detecting when views were dismissed (path got shorter)
    /// 2. Triggering dismissal actions for removed views
    /// 3. Updating the coordinator stack to match SwiftUI's navigation state
    public func handlePushPathChange(_ newPath: [NavigationStackItem]) {
        // Set flag to prevent circular updates
        isDismissalInProgress = true

        // Use a separate queue to avoid deadlock with the main observation
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            defer { self.isDismissalInProgress = false }

            let currentStack = self.navigationStack
            let stackItems = currentStack.value
            let currentRegularViews = stackItems.filter {
                $0.presentationType == .push && !($0.presentable is any Coordinatable)
            }

            // Check if views were dismissed (path got shorter)
            if newPath.count < currentRegularViews.count {
                let itemsToRemove = currentRegularViews.count - newPath.count
                let newStackCount = stackItems.count - itemsToRemove

                // Trigger dismissal actions for removed items
                for index in newStackCount ..< stackItems.count {
                    if let dismissalAction = currentStack.dismissalAction[index] {
                        dismissalAction()
                    }
                }

                // Update coordinator stack to match navigation state
                self.coordinator.popTo(newStackCount - 1, nil)
            }
        }
    }

    /// Attempts to extract the root content from a coordinator without creating a nested NavigationStack.
    ///
    /// This method tries to access the coordinator's root content directly to avoid the nested
    /// NavigationStack problem that occurs when pushing coordinators.
    ///
    /// - Parameter coordinator: The coordinator to extract root content from
    /// - Returns: The root content view if extraction is successful, nil otherwise
    private func extractRootContent(from _: any Coordinatable) -> (any View)? {
        // For now, return nil to use the fallback approach
        // This can be enhanced later with reflection or protocol extensions
        return nil
    }
}
