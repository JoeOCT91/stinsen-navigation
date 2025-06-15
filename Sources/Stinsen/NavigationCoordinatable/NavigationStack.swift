import Combine
import Foundation
import SwiftUI

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
public class NavigationRoot: ObservableObject {
    @Published var item: NavigationRootItem

    init(item: NavigationRootItem) {
        self.item = item
    }
}

struct NavigationRootItem {
    let keyPath: Int
    let input: Any?
    let child: ViewPresentable
}

struct NavigationStackItem {
    let presentationType: PresentationType
    let presentable: ViewPresentable
    let keyPath: Int
    let input: Any?
}

// MARK: - NavigationStackItem Conformance
extension NavigationStackItem: Identifiable, Hashable {
    var id: Int { keyPath }

    static func == (lhs: NavigationStackItem, rhs: NavigationStackItem) -> Bool {
        return lhs.keyPath == rhs.keyPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
    }
}

/// Represents a stack of routes
public class NavigationStack<T: NavigationCoordinatable>: ObservableObject {
    @Published var value: [NavigationStackItem]
    var dismissalAction: [Int: () -> Void] = [:]

    var poppedTo = PassthroughSubject<Int, Never>()
    let initial: PartialKeyPath<T>
    let initialInput: Any?

    weak var parent: ChildDismissable?
    private var _root: NavigationRoot?

    public init(initial: PartialKeyPath<T>, _ initialInput: Any? = nil) {
        self.value = []
        self.initial = initial
        self.initialInput = initialInput
        self._root = nil
    }

    var root: NavigationRoot {
        if let root = _root {
            return root
        }
        fatalError("Root must be set before accessing. Call ensureRoot(with:) first.")
    }

    func ensureRoot(with coordinator: T) {
        guard _root == nil else { return }

        let transition = coordinator[keyPath: initial] as! NavigationOutputable
        let presentable = transition.using(coordinator: coordinator, input: initialInput as Any)

        let rootItem = NavigationRootItem(
            keyPath: initial.hashValue,
            input: initialInput,
            child: presentable
        )

        self._root = NavigationRoot(item: rootItem)
    }
}

/// Convenience checks against the navigation stack's contents
extension NavigationStack {
    /**
        The Hash of the route at the top of the stack
        - Returns: the hash of the route at the top of the stack or -1
     */
    public var currentRoute: Int {
        return value.last?.keyPath ?? -1
    }

    /**
    Checks if a particular KeyPath is in a stack
     - Parameter keyPathHash:The hash of the keyPath
     - Returns: Boolean indiacting whether the route is in the stack
     */
    public func isInStack(_ keyPathHash: Int) -> Bool {
        return value.contains { $0.keyPath == keyPathHash }
    }

    /**
    Checks if a parent coordinator
     - Returns: Boolean indiacting whether the coordinator has a parent
     */
    public func hasParent() -> Bool {
        return self.parent != nil
    }
}
