import Foundation

public protocol ChildDismissable: AnyObject {
    func dismissChild<CoordinatorType: Coordinatable>(coordinator: CoordinatorType, action: (() -> Void)?)
}
