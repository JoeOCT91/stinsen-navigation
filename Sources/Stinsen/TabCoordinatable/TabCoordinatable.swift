import Foundation
import SwiftUI

// MARK: - Tab Lifecycle Protocol
public protocol TabLifecycle {
    func tabWillAppear()
    func tabDidAppear()
    func tabWillDisappear()
    func tabDidDisappear()
}

// MARK: - Enhanced TabCoordinatable Protocol
/// The TabCoordinatable is used to represent a coordinator with a TabView
public protocol TabCoordinatable: Coordinatable {
    typealias Route = TabRoute
    typealias Router = TabRouter<Self>
    associatedtype RouterStoreType

    var routerStorable: RouterStoreType { get }

    // Generic child for type safety
    var child: TabChild<Self> { get }

    associatedtype CustomizeViewType: View

    /**
     Implement this function if you wish to customize the view on all views and child coordinators
    
     - Parameter view: The input view.
     - Returns: The modified view.
     */
    func customize(_ view: AnyView) -> CustomizeViewType

    /**
     Searches the tab-bar for the first route that matches the route and makes it the active tab.
    
     - Parameter route: The route that will be focused.
     */
    @discardableResult func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Output

    /**
     Searches the tab-bar for the first route that matches the route and makes it the active tab.
    
     - Parameter route: The route that will be focused.
     */
    @discardableResult func focusFirst<Output: View>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Self

    /**
     Safe version of focusFirst that returns a Result
     */
    func safeFocusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Result<Output, TabFocusError>

    /**
     Safe version of focusFirst that returns a Result
     */
    func safeFocusFirst<Output: View>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Result<Self, TabFocusError>
}

// MARK: - Default Implementations
extension TabCoordinatable {
    public var routerStorable: Self {
        self
    }

    public func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        print("Warning: dismissChild not implemented for TabCoordinatable")
        action?()
    }

    public var parent: ChildDismissable? {
        get {
            return child.parent
        }
        set {
            child.parent = newValue
        }
    }

    // MARK: - Setup Methods

    internal func setupAllTabs() {
        // Guard against multiple calls - tabs should only be set up once
        guard !child.isInitialized else {
            return
        }

        guard let descriptors = child.routeDescriptors else {
            return
        }
        let items = descriptors.map { $0.makeItem(self) }

        // Use the safe method to set items
        self.child.setAllItems(items)
    }

    /// Flag to prevent multiple eager initialization calls.
    ///
    /// ## Purpose
    /// Guards against duplicate calls to `eagerlyInitializeTabs()` which could cause:
    /// - Redundant tab setup operations
    /// - Multiple calls to expensive `makeItem` factories
    /// - Unnecessary object creation and memory allocation
    ///
    /// ## Usage
    /// Set to `true` on first call to `eagerlyInitializeTabs()`, preventing subsequent
    /// calls from performing any work. This is especially important when:
    /// - `.task` modifier triggers multiple times due to view lifecycle
    /// - Manual initialization calls are made alongside automatic initialization
    /// - Navigation operations trigger setup checks
    ///
    /// ## Thread Safety
    /// Uses `objc_setAssociatedObject` with `OBJC_ASSOCIATION_RETAIN_NONATOMIC`
    /// for atomic access across threads.
    private var hasEagerlyInitialized: Bool {
        get {
            objc_getAssociatedObject(self, &hasEagerlyInitializedKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(
                self, &hasEagerlyInitializedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Flag to prevent multiple presentable force-creation operations.
    ///
    /// ## Purpose
    /// Guards against repeated execution of the expensive presentable creation loop
    /// in `eagerlyInitializeTabs()`. This prevents:
    /// - Multiple coordinator instantiations for the same tab
    /// - Redundant view hierarchy creation
    /// - Memory leaks from duplicate object graphs
    /// - Performance degradation from repeated heavy operations
    ///
    /// ## Why Separate from hasEagerlyInitialized?
    /// While `hasEagerlyInitialized` prevents the entire eager initialization process,
    /// this flag specifically targets the most expensive part - forcing lazy presentables
    /// to be created. This allows for:
    /// - Fine-grained control over expensive operations
    /// - Better debugging and performance monitoring
    /// - Potential future optimizations where setup and presentable creation are decoupled
    ///
    /// ## Performance Impact
    /// Presentable creation can involve:
    /// - Complex coordinator initialization
    /// - Dependency injection setup
    /// - View model creation and binding
    /// - Network service initialization
    /// - Database connection establishment
    ///
    /// Preventing duplicate execution of this loop can save significant CPU time
    /// and memory allocation, especially with multiple tabs containing heavy coordinators.
    ///
    /// ## Thread Safety
    /// Uses `objc_setAssociatedObject` with `OBJC_ASSOCIATION_RETAIN_NONATOMIC`
    /// for atomic access across threads.
    private var hasForcedPresentableCreation: Bool {
        get {
            objc_getAssociatedObject(self, &hasForcedPresentableCreationKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(
                self, &hasForcedPresentableCreationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Forces all tabs to be created immediately, ensuring navigation is available.
    /// Call this during app initialization for immediate navigation availability.
    private func eagerlyInitializeTabs() {
        guard !hasEagerlyInitialized else { return }
        hasEagerlyInitialized = true

        setupAllTabs()

        // Force creation of all presentables to ensure they're ready for navigation
        // Only do this expensive operation once
        guard !hasForcedPresentableCreation else { return }
        hasForcedPresentableCreation = true

        for index in 0..<child.tabCount {
            if let item = child.item(at: index) {
                let presentable = item.presentable  // Force lazy loading
                print(
                    "📱 TabCoordinatable: Created presentable at index \(index): \(type(of: presentable))"
                )
            } else {
                print("❌ TabCoordinatable: No item found at index \(index)")
            }
        }
        print("🎉 TabCoordinatable: Eager initialization completed")
    }

    /// Asynchronously initializes all tabs for immediate navigation availability.
    /// Called automatically by TabCoordinatableView via .task modifier.
    internal func initializeTabsAsync() async {
        eagerlyInitializeTabs()
    }

    // MARK: - Default Customization

    public func customize(_ view: AnyView) -> some View {
        return view
    }

    public func view() -> some View {
        TabCoordinatableView(
            coordinator: self,
            customize: customize
        )
    }

    // MARK: - Tab Focus Methods

    @discardableResult public func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Output {
        switch safeFocusFirst(route) {
        case .success(let output):
            return output
        case .failure(let error):
            fatalError("TabCoordinatable: \(error.localizedDescription)")
        }
    }

    @discardableResult public func focusFirst<Output: View>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Self {
        switch safeFocusFirst(route) {
        case .success(let result):
            return result
        case .failure(let error):
            fatalError("TabCoordinatable: \(error.localizedDescription)")
        }
    }

    // MARK: - Safe focus methods (Public API for error handling)

    public func safeFocusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Result<Output, TabFocusError> {
        // Initialize tabs if needed
        if !child.isInitialized {
            setupAllTabs()
        }

        // Find the tab index
        guard
            let descriptors = child.routeDescriptors,
            let index = descriptors.firstIndex(where: { $0.matches(route) })
        else {
            return .failure(.tabNotFound)
        }

        // Switch to that tab
        child.switchToTab(at: index)

        // Get the item and ensure presentable is created
        guard let item = child.item(at: index) else {
            return .failure(.tabNotFound)
        }

        // Force presentable creation to ensure it's ready for immediate navigation
        let presentable = item.presentable

        if let casted = presentable as? Output {
            return .success(casted)
        } else {
            let actual = type(of: presentable)
            return .failure(.invalidCast(expected: Output.self, actual: actual))
        }
    }

    public func safeFocusFirst<Output: View>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Result<Self, TabFocusError> {
        // Initialize tabs if needed
        if !child.isInitialized {
            setupAllTabs()
        }

        // Find the tab index
        guard
            let descriptors = child.routeDescriptors,
            let index = descriptors.firstIndex(where: { $0.matches(route) })
        else {
            return .failure(.tabNotFound)
        }

        // Switch to that tab
        child.switchToTab(at: index)

        return .success(self)
    }
}

// MARK: - Tab Lifecycle Support
extension TabCoordinatable where Self: TabLifecycle {
    public func notifyTabLifecycle(from oldIndex: Int?, to newIndex: Int) {
        if let oldIndex = oldIndex, oldIndex != newIndex {
            tabWillDisappear()
        }

        tabWillAppear()

        // Delay appearance notifications
        DispatchQueue.main.async { [weak self] in
            if let oldIndex = oldIndex, oldIndex != newIndex {
                self?.tabDidDisappear()
            }
            self?.tabDidAppear()
        }
    }
}

/// Associated object key for the `hasEagerlyInitialized` flag.
///
/// ## Purpose
/// Provides a unique memory address for storing the eager initialization state
/// as an associated object on TabCoordinatable instances.
///
/// ## Why Associated Objects?
/// Since TabCoordinatable is a protocol, we cannot add stored properties directly.
/// Associated objects allow us to attach state to protocol instances without:
/// - Requiring protocol adopters to implement storage
/// - Breaking the existing API
/// - Adding memory overhead to all instances (only used when needed)
///
/// ## Memory Management
/// The associated object is automatically cleaned up when the coordinator
/// instance is deallocated, preventing memory leaks.
private var hasEagerlyInitializedKey: UInt8 = 0

/// Associated object key for the `hasForcedPresentableCreation` flag.
///
/// ## Purpose
/// Provides a unique memory address for storing the presentable creation state
/// as an associated object on TabCoordinatable instances.
///
/// ## Design Pattern
/// Uses the same associated object pattern as `hasEagerlyInitializedKey`
/// but with a separate key to allow independent tracking of different
/// bottleneck prevention mechanisms.
///
/// ## Performance Benefit
/// Enables fine-grained control over expensive operations without requiring
/// protocol adopters to manage additional state variables.
private var hasForcedPresentableCreationKey: UInt8 = 0
