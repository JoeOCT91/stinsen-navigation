import Foundation
import SwiftUI

/// Represents an item in the navigation stack with type-safe presentable content.
///
/// NavigationStackItem encapsulates all information needed to present a single
/// navigation destination, including its presentation type, content, and metadata.
/// Items are used by PresentationHelper to determine how to present content
/// (push, modal, or full-screen).
///
/// ## Key Features
/// - **Type-safe identification**: Uses KeyPath hash for unique identification
/// - **Presentation type awareness**: Knows how it should be presented
/// - **Input parameter storage**: Maintains reference to creation parameters
/// - **SwiftUI compatibility**: Conforms to Identifiable and Hashable
/// - **Associated type preservation**: Maintains type information where possible
public struct NavigationStackItem {
    /// The presentation type that determines how this item should be displayed
    public let presentationType: PresentationType

    /// The type-safe presentable wrapper that preserves associated type information
    public let presentableWrapper: AnyPresentableWrapper

    /// Unique identifier derived from the route's KeyPath hash
    public let keyPath: Int

    /// Optional input parameters passed to the route creation closure
    public let input: Any?

    /// Computed property for backward compatibility
    public var presentable: any ViewPresentable {
        return presentableWrapper.presentable
    }

    /// Initializes a NavigationStackItem with type-safe presentable wrapping.
    ///
    /// - Parameters:
    ///   - presentationType: How this item should be presented
    ///   - presentable: The presentable content to wrap
    ///   - keyPath: Unique identifier for the item
    ///   - input: Optional input parameters
    init<P: ViewPresentable>(
        presentationType: PresentationType,
        presentable: P,
        keyPath: Int,
        input: Any?
    ) {
        self.presentationType = presentationType
        presentableWrapper = AnyPresentableWrapper(presentable)
        self.keyPath = keyPath
        self.input = input
    }
}

// MARK: - NavigationStackItem Conformance

extension NavigationStackItem: Identifiable, Hashable {
    /// Unique identifier for SwiftUI list and navigation operations
    public var id: Int { keyPath }

    /// Equality comparison based on keyPath for efficient stack operations
    ///
    /// Two NavigationStackItems are considered equal if they have the same keyPath,
    /// regardless of their input parameters or presentation type. This allows for
    /// efficient stack manipulation and duplicate detection.
    ///
    /// - Parameters:
    ///   - lhs: Left-hand side NavigationStackItem
    ///   - rhs: Right-hand side NavigationStackItem
    /// - Returns: `true` if both items have the same keyPath, `false` otherwise
    public static func == (lhs: NavigationStackItem, rhs: NavigationStackItem) -> Bool {
        return lhs.keyPath == rhs.keyPath
    }

    /// Hash implementation for Set and Dictionary operations
    ///
    /// Uses the keyPath as the primary hash component, ensuring that items
    /// with the same route have the same hash value for efficient collection operations.
    ///
    /// - Parameter hasher: The hasher to combine values into
    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
    }
}
