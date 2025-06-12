import Foundation
import SwiftUI


// MARK: - AnyCoordinator Wrapper
public final class AnyCoordinator<Base: Coordinatable>: Coordinatable {
    private let base: Base

    public var parent: (any ChildDismissable)? {
        get {
            base.parent
        } set {
            base.parent = newValue
        }
    }

    public var id: String {
        base.id
    }

    public init(_ base: Base) {
        self.base = base
    }

    public func view() -> some View {
        base.view()
    }

    public func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        base.dismissChild(coordinator: coordinator, action: action)
    }
}
