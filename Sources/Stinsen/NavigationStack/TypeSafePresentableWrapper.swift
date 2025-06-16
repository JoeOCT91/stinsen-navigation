import Foundation
import SwiftUI

///
/// Use this only when absolutely necessary for interfacing with
/// existing APIs that require type erasure.
public struct PresentableWrapper {
    private let _createView: () -> AnyView
    private let _presentable: any ViewPresentable

    public init<P: ViewPresentable>(_ presentable: P) {
        _presentable = presentable
        _createView = { AnyView(presentable.view()) }
    }

    public func createView() -> AnyView {
        return _createView()
    }

    /// Backward compatibility property
    public var presentable: any ViewPresentable {
        return _presentable
    }
}
