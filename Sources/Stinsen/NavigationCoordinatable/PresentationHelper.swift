import Combine
import Foundation
import SwiftUI

/// A helper class that manages presentation state for NavigationCoordinatable coordinators.
///
/// PresentationHelper handles the presentation logic for navigation items, including
/// modal presentations, full-screen presentations, and push navigation. It observes
/// the coordinator's navigation stack and updates presentation state accordingly.
final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
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
        _coordinator = ObservedObject(wrappedValue: coordinator)

        // Initialize current stack tracking
        currentStackId = ObjectIdentifier(coordinator.stack)

        observeCurrentStack()
    }

    func updatePresentationStates() {
        let currentStack = navigationStack
        let stackItems = currentStack.value

        // Check only the last push item (most efficient)
        let lastPushItem = stackItems.last { $0.presentationType == .push }

        if let lastItem = lastPushItem {
            // Check if last item is a coordinator
            if lastItem.presentable is any Coordinatable {
                // Update coordinator push
                if pushedCoordinator?.id != lastItem.id {
                    pushedCoordinator = lastItem
                    pushPath = [] // Clear regular push path when coordinator is active
                }
            } else {
                // Update regular push path
                let regularItems = stackItems.filter {
                    $0.presentationType == .push && !($0.presentable is any Coordinatable)
                }
                if pushPath != regularItems {
                    pushPath = regularItems
                    pushedCoordinator = nil // Clear coordinator when regular views are active
                }
            }
        } else {
            // No push items, clear everything
            if !pushPath.isEmpty || pushedCoordinator != nil {
                pushPath = []
                pushedCoordinator = nil
            }
        }
    }

    private func observeCurrentStack() {
        // Observe current stack value changes
        navigationStack.$value.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updatePresentationStates()
            }
        }
        .store(in: &cancellables)

        // Observe push path changes to detect SwiftUI navigation dismissals
        $pushPath.sink { [weak self] newPath in
            guard let self = self else { return }
            self.handlePushPathChange(newPath)
        }
        .store(in: &cancellables)

        // Observe coordinator dismissals
        $pushedCoordinator.sink { [weak self] coordinator in
            guard let self = self else { return }
            self.handleCoordinatorChange(coordinator)
        }
        .store(in: &cancellables)
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

    /// Handles changes to the push path to detect SwiftUI navigation dismissals
    private func handlePushPathChange(_ newPath: [NavigationStackItem]) {
        let currentStack = navigationStack
        let currentStackItems = currentStack.value.filter { $0.presentationType == .push && !($0.presentable is any Coordinatable) }

        // Check if the path was reduced (items were dismissed)
        if newPath.count < currentStackItems.count {
            // Sync coordinator stack with SwiftUI navigation state
            syncStackWithNavigationPath(newPath)
        }
    }

    /// Handles changes to the pushed coordinator to detect coordinator dismissals
    private func handleCoordinatorChange(_ coordinator: NavigationStackItem?) {
        if coordinator == nil {
            // Coordinator was dismissed
            syncCoordinatorDismissal()
        }
    }

    /// Syncs the coordinator stack with the current SwiftUI navigation path
    private func syncStackWithNavigationPath(_ currentPath: [NavigationStackItem]) {
        let currentStack = navigationStack
        let stackItems = currentStack.value

        // Find the target index to pop to
        let targetCount = currentPath.count
        let currentRegularViewCount = stackItems.filter { $0.presentationType == .push && !($0.presentable is any Coordinatable) }.count

        if targetCount < currentRegularViewCount {
            // Calculate how many items to remove from the coordinator stack
            let itemsToRemove = currentRegularViewCount - targetCount
            let newStackCount = stackItems.count - itemsToRemove

            // Trigger dismissal actions for removed items
            triggerDismissalActions(from: newStackCount, to: stackItems.count)

            // Update coordinator stack to match navigation state
            coordinator.popTo(newStackCount - 1, nil)
        }
    }

    /// Syncs coordinator dismissal with the coordinator stack
    private func syncCoordinatorDismissal() {
        let currentStack = navigationStack
        let stackItems = currentStack.value

        // Find the last coordinator in the stack
        if let lastCoordinatorIndex = stackItems.lastIndex(where: { $0.presentable is any Coordinatable }) {
            // Trigger dismissal action for the coordinator
            if let dismissalAction = currentStack.dismissalAction[lastCoordinatorIndex] {
                dismissalAction()
            }

            // Pop the coordinator from the stack
            coordinator.popTo(lastCoordinatorIndex - 1, nil)
        }
    }

    /// Triggers dismissal actions for items in the specified range
    private func triggerDismissalActions(from startIndex: Int, to endIndex: Int) {
        let currentStack = navigationStack

        for index in startIndex ..< endIndex {
            if let dismissalAction = currentStack.dismissalAction[index] {
                dismissalAction()
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
