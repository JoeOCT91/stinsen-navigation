//
//  NavigationStackItem.swift
//  Stinsen
//
//  Created by Yousef Mohamed on 08/06/2025.
//

import Foundation

/// Represents a single item in the navigation stack
struct NavigationStackItem: Hashable, Identifiable {
    /// The type of presentation (push, modal, fullScreen)
    let presentationType: PresentationType
    /// The view to present
    let presentable: ViewPresentable
    /// Hash of the keyPath for routing
    let keyPath: Int
    /// Optional input data for the view
    let input: Any?

    // MARK: - Identifiable Conformance

    /// Unique identifier for SwiftUI's navigation system
    var id: Int { keyPath }

    // MARK: - Hashable Conformance

    static func == (lhs: NavigationStackItem, rhs: NavigationStackItem) -> Bool {
        lhs.keyPath == rhs.keyPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
    }
}
