import Combine
import Foundation
import SwiftUI

/// A leaner helper that derives *all* UI‑relevant state from the coordinator's ``NavigationStack``.
/// It replaces the original ~600‑line implementation with ±150 lines, while preserving behaviour.
///
/// Key ideas
/// ----------
/// • **Single source of truth** –‐ the coordinator's stack. The helper *derives* push‑path,
///   modal & full‑screen items instead of trying to keep them in sync manually.
/// • **Functional helpers** on `NavigationStackItem` for clear intent (`isCoordinator`, `isModal`, …).
/// • **One refresh() function** that maps the current stack to the four `@Published` properties; no
///   multi‑step mutation or debug prints necessary.
/// • **Unified dismiss(kind:)** – handles coordinator / modal / full‑screen dismissal with the
///   same code path.
///
/// Usage remains identical: create once next to your coordinator and call the public `handle*`
/// methods from SwiftUI `onDisappear`/`onDismiss` callbacks.​
public final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    // MARK: ‑ State consumed by SwiftUI

    // MARK: - Computed state for SwiftUI

    /// All push items in the stack (including coordinators and regular views).
    /// This supports the shared navigation stack approach where multiple coordinators
    /// can be pushed and share the same NavigationStack without nesting conflicts.
    public var pushPath: [NavigationStackItem] {
        return stack.value.filter(\.isPush)
    }

    /// The first (and only) pushed NavigationCoordinatable in the stack.
    /// NavigationCoordinatable coordinators manage their own stack independently.
    public var pushedCoordinator: NavigationStackItem? {
        stack.value.filter(\.isPush).first(where: \.isNavigationCoordinator)
    }

    /// All pushed coordinators in the stack (includes both NavigationCoordinatable and ChildCoordinatable).
    /// ChildCoordinatable coordinators share the parent's stack, so multiple can exist.
    public var pushedCoordinators: [NavigationStackItem] {
        return stack.value.filter(\.isPush).filter(\.isCoordinator)
    }

    /// The current modal item (if any).
    public var modalItem: NavigationStackItem? {
        stack.value.last(where: \.isModal)
    }

    /// The current full-screen item (if any).
    public var fullScreenItem: NavigationStackItem? {
        stack.value.last(where: \.isFullScreen)
    }

    @Published public private(set) var rootChangeId = UUID()

    // MARK: - Computed bindings for SwiftUI

    /// Binding for modal presentation - provides more control over modal state
    public var modalBinding: Binding<NavigationStackItem?> {
        Binding(
            get: { [weak self] in self?.modalItem },
            set: { [weak self] newValue in
                // If setting to nil, dismiss the modal
                if newValue == nil {
                    self?.handleModalDismissal()
                }
                // Note: Setting to a non-nil value is handled by the navigation system
            }
        )
    }

    /// Binding for full-screen presentation - provides more control over full-screen state
    public var fullScreenBinding: Binding<NavigationStackItem?> {
        Binding(
            get: { [weak self] in self?.fullScreenItem },
            set: { [weak self] newValue in
                // If setting to nil, dismiss the full-screen
                if newValue == nil {
                    self?.handleFullScreenDismissal()
                }
                // Note: Setting to a non-nil value is handled by the navigation system
            }
        )
    }

    /// Binding for push path - provides more control over navigation stack
    public var pushPathBinding: Binding<[NavigationStackItem]> {
        Binding(
            get: { [weak self] in self?.pushPath ?? [] },
            set: { [weak self] newValue in
                self?.handlePushPathChange(newValue)
            }
        )
    }

    /// Binding for pushed coordinator - provides more control over coordinator presentation
    public var pushedCoordinatorBinding: Binding<NavigationStackItem?> {
        Binding(
            get: { [weak self] in self?.pushedCoordinator },
            set: { [weak self] newValue in
                // If setting to nil, dismiss the coordinator
                if newValue == nil {
                    self?.handleCoordinatorDismissal()
                }
                // Note: Setting to a non-nil value is handled by the navigation system
            }
        )
    }

    // MARK: ‑ Internals

    public private(set) var coordinator: T
    private var cancellables = Set<AnyCancellable>()
    private var stack: NavigationStack<T> { coordinator.stack }

    /// Router instance for navigation operations
    public let router: NavigationRouter<T>

    /// View factory for creating navigation views
    private let viewFactory: NavigationViewFactory

    /// Cached root to avoid repeated ensureRoot calls
    private var _cachedRoot: NavigationRoot?

    // MARK: ‑ Init

    public init(coordinator: T, viewFactory: NavigationViewFactory = DefaultNavigationViewFactory()) {
        self.coordinator = coordinator
        self.viewFactory = viewFactory

        // Create router and store it in RouterStore
        // Since id is always -1 for NavigationCoordinatableView, we can hardcode it
        router = NavigationRouter(
            id: -1,
            coordinator: coordinator.routerStorable
        )
        RouterStore.shared.store(router: router)

        bindToStack()
    }

    // MARK: ‑ Bindings

    private func bindToStack() {
        // Trigger UI updates whenever the stack changes.
        stack.$value
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logStackState()
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Notify SwiftUI when the *root* itself swaps out (e.g. tab change).
        // Access root only once here to minimize ensureRoot calls
        stack.safeRoot(with: coordinator).$item
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rootChangeId = UUID()
            }
            .store(in: &cancellables)
    }

    // MARK: ‑ Debug logging

    private func logStackState() {
        #if DEBUG
            logStackStateDebug()
        #endif
    }

    // MARK: ‑ Dismissal hooks (call from SwiftUI)

    public func handleCoordinatorDismissal() { dismiss { $0.isCoordinator } }
    public func handleModalDismissal() { dismiss { $0.isModal } }
    public func handleFullScreenDismissal() { dismiss { $0.isFullScreen } }

    /// Handles dismissal of a specific coordinator at the given index
    public func handleCoordinatorDismissal(at index: Int) {
        let coordinators = pushedCoordinators
        guard index >= 0 && index < coordinators.count else {
            logInvalidCoordinatorIndex(index: index, coordinatorCount: coordinators.count)
            return
        }

        let coordinatorToDismiss = coordinators[index]
        guard let stackIndex = stack.value.firstIndex(where: { $0.id == coordinatorToDismiss.id }) else {
            logCoordinatorNotFoundInStack()
            return
        }

        let targetIndex = stackIndex - 1
        logDismissingCoordinator(stackIndex: stackIndex, targetIndex: targetIndex)

        stack.dismissalAction[stackIndex]?()
        coordinator.popTo(targetIndex, nil)
    }

    /// Call from `NavigationStack`'s `onChange(of: pushPath)`.
    public func handlePushPathChange(_ newPath: [NavigationStackItem]) {
        guard newPath.count < pushPath.count else { return }

        let removedCount = pushPath.count - newPath.count
        let currentStackSize = stack.value.count
        let targetIndex = currentStackSize - removedCount - 1

        logPushPathChange(
            oldCount: pushPath.count,
            newCount: newPath.count,
            removedCount: removedCount,
            stackSize: currentStackSize,
            targetIndex: targetIndex
        )

        // Ensure target index is valid
        guard targetIndex >= -1 && targetIndex < currentStackSize else {
            logInvalidTargetIndex(
                targetIndex: targetIndex,
                stackSize: currentStackSize,
                stackItems: stack.value.map { type(of: $0.presentable) }
            )
            return
        }

        coordinator.popTo(targetIndex, nil)
    }

    // MARK: ‑ Helpers

    private func dismiss(kind predicate: (NavigationStackItem) -> Bool) {
        guard let idx = stack.value.lastIndex(where: predicate) else {
            logDismissNoItemFound()
            return
        }

        let currentStackSize = stack.value.count
        let targetIndex = idx - 1

        logDismissOperation(
            itemIndex: idx,
            stackSize: currentStackSize,
            targetIndex: targetIndex,
            itemType: type(of: stack.value[idx].presentable),
            stackItems: stack.value.enumerated().map { "\($0.offset): \(type(of: $0.element.presentable))" }
        )

        // Ensure target index is valid
        guard targetIndex >= -1 else {
            logInvalidDismissTargetIndex(targetIndex: targetIndex, itemIndex: idx)
            return
        }

        // Additional safety check - ensure the stack hasn't changed between calculation and execution
        guard idx < stack.value.count else {
            logStackChangedDuringDismiss(itemIndex: idx, stackSize: stack.value.count)
            return
        }

        stack.dismissalAction[idx]?() // invoke stored closure if any
        coordinator.popTo(targetIndex, nil) // mutate underlying stack
    }
}

// MARK: ‑ Convenience predicates

public extension NavigationStackItem {
    var isCoordinator: Bool { presentable is any Coordinatable }
    var isNavigationCoordinator: Bool { presentable is any NavigationCoordinatable }
    var isChildCoordinator: Bool { presentable is any ChildCoordinatable }
    var isRegular: Bool { presentationType == .push && !isCoordinator }
    var isPush: Bool { presentationType == .push }
    var isModal: Bool { presentationType == .modal }
    var isFullScreen: Bool { presentationType == .fullScreen }
}

// MARK: ‑ View Creation Delegation (unchanged API)

public extension PresentationHelper {
    /// Creates a SwiftUI view for destination content using the configured factory.
    ///
    /// This method delegates to the view factory to create destination content,
    /// maintaining the same API as before while separating navigation logic from view creation.
    ///
    /// - Parameter item: The navigation stack item to create a view for
    /// - Returns: A SwiftUI view for the destination content
    func createDestinationContent(for item: NavigationStackItem) -> some View {
        AnyView(viewFactory.createDestinationContent(for: item))
    }

    /// Creates a SwiftUI view for coordinator content using the configured factory.
    ///
    /// This method delegates to the view factory to create coordinator content,
    /// maintaining the same API as before while separating navigation logic from view creation.
    ///
    /// - Parameter item: The navigation stack item containing a coordinator
    /// - Returns: A SwiftUI view for the coordinator content
    func createCoordinatorContent(for item: NavigationStackItem) -> some View {
        AnyView(viewFactory.createCoordinatorContent(for: item))
    }
}

// MARK: - Debug Extension

#if DEBUG
    extension PresentationHelper {
        /// Debug logging for navigation stack state
        /// Only available in debug builds to avoid performance impact in production
        func logStackStateDebug() {
            let items = stack.value
            let stackItems = items.enumerated().map { (index: $0, type: String(describing: $1.presentationType), presentable: String(describing: type(of: $1.presentable))) }

            let modalItem = self.modalItem.map { String(describing: type(of: $0.presentable)) }
            let fullScreenItem = self.fullScreenItem.map { String(describing: type(of: $0.presentable)) }
            let pushedCoordinator = self.pushedCoordinator.map { String(describing: type(of: $0.presentable)) }

            let childCoordinators = pushedCoordinators.filter(\.isChildCoordinator)
            let childCoordinatorNames = childCoordinators.map { String(describing: type(of: $0.presentable)) }

            let coordinatorCounts = (
                total: pushedCoordinators.count,
                navigation: pushedCoordinators.filter(\.isNavigationCoordinator).count,
                child: childCoordinators.count
            )

            StinsenLogger.logStackState(
                itemCount: items.count,
                items: stackItems,
                modalItem: modalItem,
                fullScreenItem: fullScreenItem,
                pushedCoordinator: pushedCoordinator,
                childCoordinators: childCoordinatorNames,
                pushPathCount: pushPath.count,
                coordinatorCounts: coordinatorCounts
            )
        }
    }
#endif

// MARK: - Logging Methods

private extension PresentationHelper {
    func logInvalidCoordinatorIndex(index: Int, coordinatorCount: Int) {
        StinsenLogger.logWarning(
            "Invalid coordinator index \(index) for \(coordinatorCount) coordinators",
            category: .presentation
        )
    }

    func logCoordinatorNotFoundInStack() {
        StinsenLogger.logWarning(
            "Coordinator not found in main stack",
            category: .presentation
        )
    }

    func logDismissingCoordinator(stackIndex: Int, targetIndex: Int) {
        StinsenLogger.logPresentation(
            "Dismissing coordinator",
            type: "coordinator",
            details: "stack index \(stackIndex), target: \(targetIndex)"
        )
    }

    func logPushPathChange(oldCount: Int, newCount: Int, removedCount: Int, stackSize: Int, targetIndex: Int) {
        StinsenLogger.logPresentation(
            "PushPath change",
            type: "navigation",
            details: "\(oldCount) -> \(newCount), removed: \(removedCount), stack: \(stackSize), target: \(targetIndex)"
        )
    }

    func logInvalidTargetIndex(targetIndex: Int, stackSize: Int, stackItems: [Any.Type]) {
        StinsenLogger.logError(
            "Invalid target index \(targetIndex) for stack size \(stackSize)",
            category: .presentation,
            context: "Stack items: \(stackItems)"
        )
    }

    func logDismissNoItemFound() {
        StinsenLogger.logWarning(
            "Dismiss: No item found matching predicate",
            category: .presentation
        )
    }

    func logDismissOperation(itemIndex: Int, stackSize: Int, targetIndex: Int, itemType: Any.Type, stackItems: [String]) {
        StinsenLogger.logPresentation(
            "Dismiss",
            type: "item",
            details: "item at index \(itemIndex), stack size: \(stackSize), target: \(targetIndex), item type: \(itemType), stack items: \(stackItems)"
        )
    }

    func logInvalidDismissTargetIndex(targetIndex: Int, itemIndex: Int) {
        StinsenLogger.logError(
            "Invalid dismiss target index \(targetIndex) for item at index \(itemIndex)",
            category: .presentation
        )
    }

    func logStackChangedDuringDismiss(itemIndex: Int, stackSize: Int) {
        StinsenLogger.logError(
            "Stack changed during dismiss - item index \(itemIndex) no longer valid for stack size \(stackSize)",
            category: .presentation
        )
    }
}
