//
//  AnyCoordinator.swift
//
//
//  Created on 06/08/2025.
//
//  A type-erased wrapper for the Coordinatable protocol that enables
//  heterogeneous collections and protocol-oriented programming patterns
//  while maintaining value semantics support.
//

import Foundation
import SwiftUI

// MARK: - AnyCoordinatorBox

/// A private box container that wraps a concrete Coordinatable type.
///
/// This box pattern is necessary to properly handle both value and reference
/// types that conform to Coordinatable. It maintains the wrapped coordinator's
/// semantics while providing a uniform interface.
fileprivate final class AnyCoordinatorBox<Base: Coordinatable>: Coordinatable {
    /// The wrapped coordinator instance
    var base: Base

    /// Initializes a new box with the given coordinator
    /// - Parameter base: The coordinator to wrap
    init(_ base: Base) {
        self.base = base
    }

    /// The parent coordinator that can dismiss this coordinator
    var parent: ChildDismissable? {
        get { base.parent }
        set { base.parent = newValue }
    }

    /// The unique identifier for this coordinator
    var id: String {
        base.id
    }

    /// Creates and returns the SwiftUI view for this coordinator
    /// - Returns: An AnyView containing the coordinator's view
    func view() -> AnyView {
        base.view()
    }

    /// Dismisses a child coordinator with an optional completion action
    /// - Parameters:
    ///   - coordinator: The child coordinator to dismiss
    ///   - action: Optional closure to execute after dismissal
    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        base.dismissChild(coordinator: coordinator, action: action)
    }
}

// MARK: - AnyCoordinator

/// A type-erased wrapper for Coordinatable protocol.
///
/// `AnyCoordinator` allows you to work with heterogeneous collections of coordinators
/// and use coordinators as properties without specifying their concrete types.
/// It properly handles both value and reference type coordinators through an
/// internal box pattern.
///
/// Example usage:
/// ```swift
/// class AppCoordinator {
///     var currentCoordinator: AnyCoordinator?
///
///     func showLogin() {
///         let loginCoordinator = LoginCoordinator()
///         currentCoordinator = AnyCoordinator(loginCoordinator)
///     }
/// }
/// ```
public final class AnyCoordinator: Coordinatable {
    /// The type-erased box containing the wrapped coordinator
    private let box: any Coordinatable

    /// Initializes a new AnyCoordinator with the given coordinator
    /// - Parameter base: The coordinator to wrap
    public init<Base: Coordinatable>(_ base: Base) {
        box = AnyCoordinatorBox(base)
    }

    /// The parent coordinator that can dismiss this coordinator
    public var parent: ChildDismissable? {
        get { box.parent }
        set { box.parent = newValue }
    }

    /// The unique identifier for this coordinator
    public var id: String {
        box.id
    }

    /// Creates and returns the SwiftUI view for this coordinator
    /// - Returns: An AnyView containing the coordinator's view
    public func view() -> AnyView {
        box.view()
    }

    /// Dismisses a child coordinator with an optional completion action
    /// - Parameters:
    ///   - coordinator: The child coordinator to dismiss
    ///   - action: Optional closure to execute after dismissal
    public func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        box.dismissChild(coordinator: coordinator, action: action)
    }
}
