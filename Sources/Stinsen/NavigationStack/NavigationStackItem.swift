import Foundation
import SwiftUI

///
/// This maintains the old interface while providing a path to migrate
/// to the new type-safe approach.
public struct NavigationStackItem: Identifiable, Hashable {
    /// The presentation type that determines how this item should be displayed
    public let presentationType: PresentationType

    /// The legacy wrapper (using LegacyPresentableWrapper)
    public let presentableWrapper: PresentableWrapper

    /// Unique identifier derived from the route's KeyPath hash
    public let keyPath: Int

    /// Optional input parameters passed to the route creation closure
    public let input: Any?

    /// Unique identifier for SwiftUI operations (uses keyPath)
    public var id: Int { keyPath }

    /// Backward compatibility property for accessing the presentable
    public var presentable: any ViewPresentable {
        return presentableWrapper.presentable
    }

    /// Legacy initializer for backward compatibility
    init<P: ViewPresentable>(
        presentationType: PresentationType,
        presentable: P,
        keyPath: Int,
        input: Any?
    ) {
        self.presentationType = presentationType
        presentableWrapper = PresentableWrapper(presentable)
        self.keyPath = keyPath
        self.input = input
    }

    /// Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
    }

    /// Equatable conformance
    public static func == (lhs: NavigationStackItem, rhs: NavigationStackItem) -> Bool {
        return lhs.keyPath == rhs.keyPath
    }
}
