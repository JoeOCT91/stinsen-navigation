import Foundation
import SwiftUI

// MARK: - NavigationChild with Type Safety

/// Wrapper around navigation stack items for type-safe navigation management
/// Used so that you don't need to write @Published manually
public class NavigationChild<T: NavigationCoordinatable>: ObservableObject {
    weak var parent: ChildDismissable?

    // Type-safe interface
    @Published private(set) var stackItems: [AnyNavigationChildItem] = []
    @Published private(set) var rootItem: AnyNavigationChildItem?

    private var _currentIndex: Int = -1

    public var currentIndex: Int {
        get {
            _currentIndex
        }
        set {
            guard newValue != _currentIndex,
                  newValue >= -1,
                  newValue < stackItems.count
            else { return }

            let oldValue = _currentIndex
            _currentIndex = newValue
            updateCurrentItem(at: newValue, wasOldValue: oldValue)
        }
    }

    // MARK: - Initializer

    public init() {
        _currentIndex = -1
    }

    // MARK: - Public Methods

    /// Sets the root item. Should be called during initialization.
    func setRootItem(_ item: AnyNavigationChildItem) {
        // Ensure @Published property updates happen on main thread
        if Thread.isMainThread {
            rootItem = item
        } else {
            DispatchQueue.main.sync {
                rootItem = item
            }
        }
    }

    /// Pushes a new item onto the navigation stack
    func pushItem(_ item: AnyNavigationChildItem) {
        if Thread.isMainThread {
            stackItems.append(item)
            _currentIndex = stackItems.count - 1
        } else {
            DispatchQueue.main.sync {
                stackItems.append(item)
                _currentIndex = stackItems.count - 1
            }
        }
    }

    /// Pops items from the stack to the specified index
    func popToIndex(_ index: Int) {
        guard index >= -1 && index < stackItems.count else { return }

        if Thread.isMainThread {
            if index == -1 {
                stackItems.removeAll()
            } else {
                stackItems.removeSubrange((index + 1)...)
            }
            _currentIndex = index
        } else {
            DispatchQueue.main.sync {
                if index == -1 {
                    stackItems.removeAll()
                } else {
                    stackItems.removeSubrange((index + 1)...)
                }
                _currentIndex = index
            }
        }
    }

    /// Update current item efficiently
    private func updateCurrentItem(at _: Int, wasOldValue _: Int) {
        // Navigation items don't have tap handlers like tabs
        // This is for future extensibility
    }

    // MARK: - Computed Properties

    public var isInitialized: Bool {
        rootItem != nil
    }

    public var stackCount: Int {
        stackItems.count
    }

    public var isEmpty: Bool {
        stackItems.isEmpty
    }

    public var currentItem: AnyNavigationChildItem? {
        if _currentIndex == -1 {
            return rootItem
        } else if _currentIndex >= 0 && _currentIndex < stackItems.count {
            return stackItems[_currentIndex]
        }
        return nil
    }
}

// MARK: - Extensions for Better API

public extension NavigationChild {
    /// Returns the item at the given index in the stack, if it exists
    internal func stackItem(at index: Int) -> AnyNavigationChildItem? {
        guard index >= 0, index < stackItems.count else { return nil }
        return stackItems[index]
    }

    /// Checks if a specific index is currently active
    func isIndexActive(_ index: Int) -> Bool {
        index == _currentIndex
    }

    /// Returns all items (root + stack) for iteration
    var allItems: [AnyNavigationChildItem] {
        var items: [AnyNavigationChildItem] = []
        if let root = rootItem {
            items.append(root)
        }
        items.append(contentsOf: stackItems)
        return items
    }
}
