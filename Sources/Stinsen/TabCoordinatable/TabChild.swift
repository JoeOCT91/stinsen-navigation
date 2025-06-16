import Foundation
import SwiftUI

// MARK: - Simplified TabChild with Minimal Overhead

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
public class TabChild<T: TabCoordinatable>: ObservableObject {
    weak var parent: ChildDismissable?

    // Type-safe interface
    public let routeDescriptors: [TabRouteDescriptor<T>]?

    @Published private(set) var activeItem: AnyTabChildItem?
    @Published private(set) var allItems: [AnyTabChildItem] = []

    private var _activeTab: Int = 0

    public var activeTab: Int {
        get {
            _activeTab
        }
        set {
            guard newValue != _activeTab,
                  newValue >= 0,
                  newValue < allItems.count
            else { return }

            let oldValue = _activeTab
            _activeTab = newValue
            updateActiveItem(at: newValue, wasOldValue: oldValue)
        }
    }

    // MARK: - Initializer

    public init(routeDescriptors: [TabRouteDescriptor<T>], activeTab: Int = 0) {
        self.routeDescriptors = routeDescriptors
        _activeTab = max(0, activeTab)
    }

    // MARK: - Public Methods

    /// Sets up all tab items. Should be called after initialization.
    func setAllItems(_ items: [AnyTabChildItem]) {
        guard !items.isEmpty else {
            StinsenLogger.logWarning("Attempting to set empty items array", category: .coordinator)
            return
        }

        // Guard against multiple calls
        guard allItems.isEmpty else {
            StinsenLogger.logWarning("setAllItems called multiple times - ignoring subsequent calls", category: .coordinator)
            return
        }

        // Ensure activeTab is within bounds
        if _activeTab >= items.count {
            _activeTab = 0
        }

        // Ensure @Published property updates happen on main thread
        if Thread.isMainThread {
            allItems = items
            activeItem = items[_activeTab]
        } else {
            DispatchQueue.main.sync {
                allItems = items
                activeItem = items[_activeTab]
            }
        }
    }

    /// Update active item efficiently
    private func updateActiveItem(at newIndex: Int, wasOldValue oldValue: Int) {
        let newItem = allItems[newIndex]
        activeItem = newItem

        // Notify of tap
        newItem.onTapped(oldValue == newIndex)
    }

    /// Safely switches to a tab by index
    public func switchToTab(at index: Int) {
        activeTab = index
    }

    // MARK: - Computed Properties

    public var isInitialized: Bool {
        !allItems.isEmpty && activeItem != nil
    }

    public var tabCount: Int {
        allItems.count
    }

    public var canGoToTab: (Int) -> Bool {
        { [weak self] index in
            guard let self = self else { return false }
            return index >= 0 && index < self.allItems.count
        }
    }
}

// MARK: - Extensions for Better API

extension TabChild {
    /// Returns the item at the given index, if it exists
    func item(at index: Int) -> AnyTabChildItem? {
        guard index >= 0, index < allItems.count else { return nil }
        return allItems[index]
    }

    /// Checks if a specific tab is currently active
    public func isTabActive(at index: Int) -> Bool {
        index == _activeTab
    }
}
