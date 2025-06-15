import Foundation
import SwiftUI

/// A wrapper around the root navigation item that provides observable behavior.
///
/// NavigationRoot serves as the observable container for the initial route in a
/// navigation coordinator. It ensures that changes to the root item trigger
/// SwiftUI view updates through the `@Published` property wrapper.
///
/// ## Usage
/// This class is typically managed internally by NavigationStack and should not
/// be instantiated directly by application code.
public class NavigationRoot: ObservableObject {
    /// The root navigation item that defines the initial route.
    ///
    /// Changes to this property trigger SwiftUI view updates for any views
    /// observing this NavigationRoot instance.
    @Published var item: NavigationRootItem

    /// Initializes a new NavigationRoot with the specified root item.
    ///
    /// - Parameter item: The NavigationRootItem that represents the initial route
    init(item: NavigationRootItem) {
        self.item = item
    }
}

/// Represents the root item in a navigation hierarchy.
///
/// NavigationRootItem contains all the information needed to render the initial
/// route of a navigation coordinator, including the route identifier, input parameters,
/// and the presentable content.
///
/// ## Properties
/// - `keyPath`: Unique identifier derived from the route's KeyPath hash
/// - `input`: Optional input parameters passed to the root route
/// - `child`: The presentable content (view or coordinator) for the root
struct NavigationRootItem {
    /// Unique identifier for this root item, derived from the route's KeyPath hash
    let keyPath: Int

    /// Optional input parameters passed to the root route creation closure
    let input: Any?

    /// The type-safe presentable wrapper that preserves associated type information
    let childWrapper: TypeSafePresentableWrapper

    /// Computed property for backward compatibility
    var child: any ViewPresentable {
        return childWrapper.presentable
    }

    /// Initializes a NavigationRootItem with type-safe presentable wrapping.
    ///
    /// - Parameters:
    ///   - keyPath: Unique identifier for the root item
    ///   - input: Optional input parameters
    ///   - child: The presentable content to wrap
    init<P: ViewPresentable>(keyPath: Int, input: Any?, child: P) {
        self.keyPath = keyPath
        self.input = input
        childWrapper = TypeSafePresentableWrapper(child)
    }
}
