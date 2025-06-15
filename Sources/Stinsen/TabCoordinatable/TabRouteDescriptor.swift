//
//  TabRouteDescriptor.swift
//  Stinsen
//
//  Created by Yousef Mohamed on 14/06/2025.
//

import Foundation
import SwiftUI

// MARK: - Documentation
//
/// `TabRouteDescriptor` is an **internal glue‑type** that bridges the strongly
/// typed world of `@TabRoute` (which stores a `Content<Coordinator, Output>`
/// instance) with Stinsen's type‑erased `TabChildItem`.
///
/// For every `@TabRoute` property the end‑developer declares, we mint exactly
/// one `TabRouteDescriptor`.  The descriptor remembers:
/// * the original `KeyPath` (`routeKeyPath`) so we can later compare routes
///   without relying on string names or fragile indices,
/// * a `makeItem` closure that—given the coordinator at runtime—produces the
///   `TabChildItem` Stinsen needs to populate a `TabView`.
///
/// ## Usage
/// End‑developers normally **never touch** this type directly; it is generated
/// for them inside their `Coordinator` initialiser:
///
/// ```swift
/// self.child = TabChild(
///     routeDescriptors: [
///         TabRouteDescriptor(\.$home),   // <- created here
///         TabRouteDescriptor(\.$todos),
///         ...
///     ]
/// )
/// ```
///
/// ## Why keep `createItem`?
///To avoid a breaking change when we renamed the property to the more expressive
/// `makeItem`, we expose `createItem` as a read‑only alias.
///
/// ## Future‑proofing & Ideas
/// * **Badges / Pill counts** –  Add another callback in `TabChildItem` so a
///   route can expose an *always‑updating* badge value (`Int?`) without the
///   end‑developer writing boilerplate.
/// * **Async presentable** –  If a tab needs async work (e.g. network fetch)
///   before displaying, consider extending `presentableFactory` with a
///   suspending version so Swift Concurrency can be used.
/// * **Conditional inclusion** –  Provide a failable or optional descriptor
///   initialiser so that a tab can be excluded at runtime (e.g. feature flags)
///   without scattering `if` statements in the coordinator.
public struct TabRouteDescriptor<Coordinator: TabCoordinatable> {
    /// Key‑path back to the `@TabRoute` property on the coordinator.
    let routeKeyPath: PartialKeyPath<Coordinator>
    /// Produces a fully‑formed `AnyTabChildItem` on demand.
    let makeItem: (Coordinator) -> AnyTabChildItem

    /// Maintained for source compatibility; use `makeItem` instead.
    var createItem: (Coordinator) -> AnyTabChildItem { makeItem }

    /// Creates a descriptor for the given `@TabRoute` property.
    /// - Parameter keyPath: Key‑path to the `Content` instance backing a tab.
    public init<Output: ViewPresentable>(
        _ keyPath: KeyPath<Coordinator, Content<Coordinator, Output>>
    ) {
        self.routeKeyPath = keyPath
        self.makeItem = { coordinator in
            let content = coordinator[keyPath: keyPath]
            let genericItem = TabChildItem<Output>(
                presentableFactory: {
                    content.createPresentable(for: coordinator) as! Output
                },
                keyPathIsEqual: { other in
                    guard let other = other as? PartialKeyPath<Coordinator> else { return false }
                    return other == keyPath
                },
                tabItem: { isActive in
                    content.createTabItem(active: isActive, for: coordinator)
                },
                onTapped: { isRepeat in
                    content.handleTap(isRepeat: isRepeat, for: coordinator)
                }
            )
            return AnyTabChildItem(genericItem)
        }
    }

    /// Returns `true` when the descriptor represents the same route.
    func matches(_ keyPath: PartialKeyPath<Coordinator>) -> Bool {
        routeKeyPath == keyPath
    }
}
