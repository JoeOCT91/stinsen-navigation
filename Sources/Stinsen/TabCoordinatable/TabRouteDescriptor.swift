import Foundation
import SwiftUI

// MARK: - TabRouteDescriptor for Type Safety
/// Wraps a key path to `Content<Coordinator, Output>` and knows how to create the
/// corresponding `TabChildItem`.  It also exposes a strongly‑typed equality
/// check so that higher‑level helpers (like `safeFocusFirst`) can unambiguously
/// find the tab that corresponds to a given key path.
public struct TabRouteDescriptor<Coordinator: TabCoordinatable> {
    /// The property key‑path originally passed (e.g. `\.home`).
    let routeKeyPath: PartialKeyPath<Coordinator>
    /// Builds the `TabChildItem` Stinsen uses internally.
    let makeItem: (Coordinator) -> TabChildItem

    /// Factory that lifts a `KeyPath` to a `Content` property into a descriptor.
    public init<Output: ViewPresentable>(_ keyPath: KeyPath<Coordinator, Content<Coordinator, Output>>) {
        self.routeKeyPath = keyPath
        self.makeItem = { coordinator in
            let content = coordinator[keyPath: keyPath]
            return TabChildItem(
                presentableFactory: {
                    content.createPresentable(for: coordinator)
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
        }
    }

    /// Convenience for equality without exposing the closure each time.
    func matches(_ keyPath: PartialKeyPath<Coordinator>) -> Bool {
        routeKeyPath == keyPath
    }
}