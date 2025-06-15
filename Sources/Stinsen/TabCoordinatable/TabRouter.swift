import SwiftUI
import Foundation

// MARK: - Tab Focus Error Types
public enum TabFocusError: Error, LocalizedError {
    case tabNotFound
    case invalidCast(expected: Any.Type, actual: Any.Type)
    case notInitialized
    case coordinatorDeallocated

    public var errorDescription: String? {
        switch self {
        case .tabNotFound:
            return "The requested tab could not be found"
        case .invalidCast(let expected, let actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        case .notInitialized:
            return "Tab coordinator is not initialized"
        case .coordinatorDeallocated:
            return "Coordinator has been deallocated"
        }
    }
}

public class TabRouter<T>: Routable {
    public var coordinator: T {
        _coordinator.value as! T
    }
    
    private var _coordinator: WeakRef<AnyObject>
    
    public init(coordinator: T) {
        self._coordinator = WeakRef(value: coordinator as AnyObject)
    }
}

public extension TabRouter where T: TabCoordinatable {
    /**
     Searches the tab-bar for the first route that matches the route and makes it the active tab.

     - Parameter route: The route that will be focused.
     */
    @discardableResult func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<T, Content<T, Output>>
    ) -> Output {
        self.coordinator.focusFirst(route)
    }
    
    /**
     Searches the tab-bar for the first route that matches the route and makes it the active tab.

     - Parameter route: The route that will be focused.
     */
    @discardableResult func focusFirst<Output: View>(
        _ route: KeyPath<T, Content<T, Output>>
    ) -> T {
        self.coordinator.focusFirst(route)
    }
}
