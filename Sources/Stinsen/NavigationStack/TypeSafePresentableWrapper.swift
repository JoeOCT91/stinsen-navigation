import Foundation
import SwiftUI

/// A generic type-safe wrapper for ViewPresentable that preserves exact view type information.
///
/// This version avoids AnyView type erasure entirely, maintaining the specific view type
/// for optimal SwiftUI performance and navigation behavior.
public struct TypeSafePresentableWrapper<ViewType: View> {
    /// The type-erased presentable for collection storage
    private let _presentable: any ViewPresentable

    /// Type-safe view creation closure that preserves the exact view type
    private let _createView: () -> ViewType

    /// Initializes a wrapper with a specific presentable type and view type.
    ///
    /// This initializer captures the presentable's specific type and creates
    /// a closure that can recreate the view without any type erasure.
    ///
    /// - Parameter presentable: The specific presentable to wrap
    public init<P: ViewPresentable>(_ presentable: P) where P.PresentedView == ViewType {
        _presentable = presentable
        _createView = { presentable.view() }
    }

    /// Returns the type-erased presentable for compatibility with existing code.
    public var presentable: any ViewPresentable {
        return _presentable
    }

    /// Creates the view using the preserved exact type information.
    ///
    /// This method uses the captured closure to create the view without
    /// any type erasure, maintaining optimal SwiftUI performance.
    ///
    /// - Returns: The presentable's view with exact type preservation
    public func createView() -> ViewType {
        return _createView()
    }
}

/// A type-erased wrapper for ViewPresentable (for backward compatibility and collections).
///
/// This wrapper allows us to store different types of presentables in collections
/// while maintaining access to their specific associated types when needed.
/// It provides a bridge between the type-safe world of specific presentables
/// and the type-erased world of collections.
public struct AnyPresentableWrapper {
    /// The type-erased presentable for collection storage
    private let _presentable: any ViewPresentable

    /// Type-safe view creation closure that preserves the original associated type
    private let _createView: () -> AnyView

    /// Initializes a wrapper with a specific presentable type.
    ///
    /// This initializer captures the presentable's specific type and creates
    /// a closure that can recreate the view without additional type erasure.
    ///
    /// - Parameter presentable: The specific presentable to wrap
    public init<P: ViewPresentable>(_ presentable: P) {
        _presentable = presentable
        _createView = { AnyView(presentable.view()) }
    }

    /// Returns the type-erased presentable for compatibility with existing code.
    public var presentable: any ViewPresentable {
        return _presentable
    }

    /// Creates the view using the preserved type information.
    ///
    /// This method uses the captured closure to create the view without
    /// additional type erasure beyond what's necessary for AnyView.
    ///
    /// - Returns: The presentable's view wrapped in AnyView
    public func createView() -> AnyView {
        return _createView()
    }
}
