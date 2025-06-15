import Foundation
import SwiftUI

/// A type-safe wrapper for ViewPresentable that preserves associated type information.
///
/// This wrapper allows us to store different types of presentables in collections
/// while maintaining access to their specific associated types when needed.
/// It provides a bridge between the type-safe world of specific presentables
/// and the type-erased world of collections.
struct TypeSafePresentableWrapper {
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
    init<P: ViewPresentable>(_ presentable: P) {
        _presentable = presentable
        _createView = { AnyView(presentable.view()) }
    }

    /// Returns the type-erased presentable for compatibility with existing code.
    var presentable: any ViewPresentable {
        return _presentable
    }

    /// Creates the view using the preserved type information.
    ///
    /// This method uses the captured closure to create the view without
    /// additional type erasure beyond what's necessary for AnyView.
    ///
    /// - Returns: The presentable's view wrapped in AnyView
    func createView() -> AnyView {
        return _createView()
    }
}
