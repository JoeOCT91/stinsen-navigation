import Foundation
import SwiftUI

/// The NavigationViewCoordinator is used to represent a coordinator with a NavigationView
public class NavigationViewCoordinator<T: Coordinatable>: ViewWrapperCoordinator<T, SwiftUI.NavigationStack<NavigationPath, AnyView>> {
    public init(_ childCoordinator: T) {
        super.init(childCoordinator) { view in
            SwiftUI.NavigationStack {
                view
            }
        }
    }
    
    @available(*, unavailable)
    public override init(_ childCoordinator: T, _ view: @escaping (AnyView) -> SwiftUI.NavigationStack<NavigationPath, AnyView>) {
        fatalError("view cannot be customized")
    }
    
    @available(*, unavailable)
    public override init(_ childCoordinator: T, _ view: @escaping (any Coordinatable) -> (AnyView) -> SwiftUI.NavigationStack<NavigationPath, AnyView>) {
        fatalError("view cannot be customized")
    }
}
