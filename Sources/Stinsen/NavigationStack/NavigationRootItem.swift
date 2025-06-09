//
//  NavigationRootItem.swift
//  Stinsen
//
//  Created by Yousef Mohamed on 09/06/2025.
//

import Foundation

struct NavigationRootItem {
    let keyPath: Int
    let input: Any?
    let child: ViewPresentable
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
public class NavigationRoot: ObservableObject {
    @Published var item: NavigationRootItem
    
    init(item: NavigationRootItem) {
        self.item = item
    }
}
