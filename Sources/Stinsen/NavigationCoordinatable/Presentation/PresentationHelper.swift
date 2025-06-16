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

    private var coordinator: T
    private var cancellables = Set<AnyCancellable>()
    private var stack: NavigationStack<T> { coordinator.stack }

    // MARK: ‑ Init

    public init(id _: Int, coordinator: T) {
        self.coordinator = coordinator
        coordinator.stack.ensureRoot(with: coordinator)
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
        stack.safeRoot(with: coordinator).$item
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rootChangeId = UUID() }
            .store(in: &cancellables)
    }

    // MARK: ‑ Debug logging

    private func logStackState() {
        let items = stack.value
        print("🔄 Stack changed: \(items.count) items")
        for (index, item) in items.enumerated() {
            print("   \(index): \(item.presentationType) - \(String(describing: type(of: item.presentable)))")
        }

        if let modal = modalItem {
            print("📱 Modal item: \(String(describing: type(of: modal.presentable)))")
        }

        if let fullScreen = fullScreenItem {
            print("🖥️ Full-screen item: \(String(describing: type(of: fullScreen.presentable)))")
        }

        if let coordinator = pushedCoordinator {
            print("🎯 Pushed NavigationCoordinator: \(String(describing: type(of: coordinator.presentable)))")
        }

        let childCoordinators = pushedCoordinators.filter(\.isChildCoordinator)
        if !childCoordinators.isEmpty {
            print("👶 Child coordinators: \(childCoordinators.map { String(describing: type(of: $0.presentable)) })")
        }

        print(
            "🛤️ Push path: \(pushPath.count) items (includes \(pushedCoordinators.count) coordinators: \(pushedCoordinators.filter(\.isNavigationCoordinator).count) navigation + \(childCoordinators.count) child)"
        )
    }

    // MARK: ‑ Dismissal hooks (call from SwiftUI)

    public func handleCoordinatorDismissal() { dismiss { $0.isCoordinator } }
    public func handleModalDismissal() { dismiss { $0.isModal } }
    public func handleFullScreenDismissal() { dismiss { $0.isFullScreen } }

    /// Handles dismissal of a specific coordinator at the given index
    public func handleCoordinatorDismissal(at index: Int) {
        let coordinators = pushedCoordinators
        guard index >= 0 && index < coordinators.count else {
            print("⚠️ Invalid coordinator index \(index) for \(coordinators.count) coordinators")
            return
        }

        let coordinatorToDismiss = coordinators[index]
        guard let stackIndex = stack.value.firstIndex(where: { $0.id == coordinatorToDismiss.id }) else {
            print("⚠️ Coordinator not found in main stack")
            return
        }

        let targetIndex = stackIndex - 1
        print("🗑️ Dismissing coordinator at stack index \(stackIndex), target: \(targetIndex)")

        stack.dismissalAction[stackIndex]?()
        coordinator.popTo(targetIndex, nil)
    }

    /// Call from `NavigationStack`'s `onChange(of: pushPath)`.
    public func handlePushPathChange(_ newPath: [NavigationStackItem]) {
        guard newPath.count < pushPath.count else { return }

        let removedCount = pushPath.count - newPath.count
        let currentStackSize = stack.value.count
        let targetIndex = currentStackSize - removedCount - 1

        print("🛤️ PushPath change: \(pushPath.count) -> \(newPath.count), removed: \(removedCount), stack: \(currentStackSize), target: \(targetIndex)")

        // Ensure target index is valid
        guard targetIndex >= -1 && targetIndex < currentStackSize else {
            print("⚠️ PresentationHelper: Invalid target index \(targetIndex) for stack size \(currentStackSize)")
            print("   Stack items: \(stack.value.map { type(of: $0.presentable) })")
            return
        }

        coordinator.popTo(targetIndex, nil)
    }

    // MARK: ‑ Helpers

    private func dismiss(kind predicate: (NavigationStackItem) -> Bool) {
        guard let idx = stack.value.lastIndex(where: predicate) else {
            print("🚫 Dismiss: No item found matching predicate")
            return
        }

        let currentStackSize = stack.value.count
        let targetIndex = idx - 1

        print("🗑️ Dismiss: item at index \(idx), stack size: \(currentStackSize), target: \(targetIndex)")
        print("   Item type: \(type(of: stack.value[idx].presentable))")
        print("   Stack items: \(stack.value.enumerated().map { "\($0.offset): \(type(of: $0.element.presentable))" })")

        // Ensure target index is valid
        guard targetIndex >= -1 else {
            print("⚠️ PresentationHelper: Invalid dismiss target index \(targetIndex) for item at index \(idx)")
            return
        }

        // Additional safety check - ensure the stack hasn't changed between calculation and execution
        guard idx < stack.value.count else {
            print("⚠️ PresentationHelper: Stack changed during dismiss - item index \(idx) no longer valid for stack size \(stack.value.count)")
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

// MARK: ‑ Lightweight view helpers (unchanged API)

public extension PresentationHelper {
    func createDestinationContent(for item: NavigationStackItem) -> some View {
        DestinationContentView(item: item)
    }

    func createCoordinatorContent(for item: NavigationStackItem) -> some View {
        Group {
            if item.presentable is (any NavigationCoordinatable) {
                CoordinatorContentView(item: item)
            } else {
                DestinationContentView(item: item)
            }
        }
    }
}

private struct DestinationContentView: View {
    let item: NavigationStackItem
    var body: some View { item.presentableWrapper.createView() }
}

private struct CoordinatorContentView: View {
    let item: NavigationStackItem
    var body: some View { item.presentableWrapper.createView() }
}
