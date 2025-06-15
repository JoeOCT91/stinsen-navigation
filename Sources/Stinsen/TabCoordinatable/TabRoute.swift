// MARK: - File: TabRouting.swift
// This file contains the generic Content, TabRoute property wrapper, TabRouteDescriptor, and TabRouteBuilder.

import Foundation
import SwiftUI

// MARK: - Content Class with Type Safety
public class Content<T: TabCoordinatable, Output: ViewPresentable> {
    let closure: ((T) -> (() -> Output))
    let tabItem: ((T) -> ((Bool) -> AnyView))
    let onTapped: ((T) -> ((Bool, Output) -> Void))

    private var output: Output?
    private let outputLock = NSLock()

    init<TabItem: View>(
        closure: @escaping ((T) -> (() -> Output)),
        tabItem: @escaping ((T) -> ((Bool) -> TabItem)),
        onTapped: @escaping ((T) -> ((Bool, Output) -> Void))
    ) {
        self.closure = closure
        self.tabItem = { coordinator in
            { isActive in AnyView(tabItem(coordinator)(isActive)) }
        }
        self.onTapped = { coordinator in
            onTapped(coordinator)
        }
    }

    /// Create (or recreate) the presentable Output for this coordinator.
    func createPresentable(for coordinator: T) -> any ViewPresentable {
        outputLock.lock(); defer { outputLock.unlock() }
        let closureOutput = self.closure(coordinator)()
        self.output = closureOutput
        return closureOutput
    }

    /// Create the tab item view for the given active state.
    func createTabItem(active: Bool, for coordinator: T) -> AnyView {
        return self.tabItem(coordinator)(active)
    }

    /// Handle a tap or repeat-tap on the tab.
    func handleTap(isRepeat: Bool, for coordinator: T) {
        outputLock.lock()
        let currentOutput = self.output
        outputLock.unlock()

        if let output = currentOutput {
            self.onTapped(coordinator)(isRepeat, output)
        }
    }
}

@propertyWrapper
public struct TabRoute<T: TabCoordinatable, Output: ViewPresentable> {
    public let wrappedValue: (T) -> () -> Output
    private let tabItemClosure: (T) -> (Bool) -> AnyView
    private let onTappedClosure: ((T) -> (Bool, Output) -> Void)?

    // 1. Coordinatable without onTapped
    public init(
        wrappedValue: @escaping (T) -> () -> Output,
        tabItem: @escaping (T) -> (Bool) -> some View
    ) where Output: Coordinatable {
        self.wrappedValue = wrappedValue
        self.tabItemClosure = { coordinator in { isActive in AnyView(tabItem(coordinator)(isActive)) } }
        self.onTappedClosure = nil
    }

    // 2. Coordinatable with onTapped
    public init(
        wrappedValue: @escaping (T) -> () -> Output,
        tabItem: @escaping (T) -> (Bool) -> some View,
        onTapped: @escaping (T) -> (Bool, Output) -> Void
    ) where Output: Coordinatable {
        self.wrappedValue = wrappedValue
        self.tabItemClosure = { coordinator in { isActive in AnyView(tabItem(coordinator)(isActive)) } }
        self.onTappedClosure = onTapped
    }

    // 3. Simple View output as AnyView, without onTapped
    public init<ViewOutput: View>(
        wrappedValue: @escaping (T) -> () -> ViewOutput,
        tabItem: @escaping (T) -> (Bool) -> some View
    ) where Output == AnyView {
        // wrap the ViewOutput in AnyView
        self.wrappedValue = { coordinator in { AnyView(wrappedValue(coordinator)()) } }
        self.tabItemClosure = { coordinator in { isActive in AnyView(tabItem(coordinator)(isActive)) } }
        self.onTappedClosure = nil
    }

    // 4. Simple View output as AnyView, with onTapped
    public init<ViewOutput: View>(
        wrappedValue: @escaping (T) -> () -> ViewOutput,
        tabItem: @escaping (T) -> (Bool) -> some View,
        onTapped: @escaping (T) -> (Bool) -> Void
    ) where Output == AnyView {
        self.wrappedValue = { coordinator in { AnyView(wrappedValue(coordinator)()) } }
        self.tabItemClosure = { coordinator in { isActive in AnyView(tabItem(coordinator)(isActive)) } }
        // lift the simpler onTapped
        self.onTappedClosure = { coordinator in { isRepeat, _ in onTapped(coordinator)(isRepeat) } }
    }

    public var projectedValue: Content<T, Output> {
        Content(
            closure: { coordinator in self.wrappedValue(coordinator) },
            tabItem: { coordinator in self.tabItemClosure(coordinator) },
            onTapped: { coordinator in
                self.onTappedClosure?(coordinator) ?? { _, _ in }
            }
        )
    }
}

// MARK: - Builder for Type-Safe Tab Configuration
@resultBuilder
public struct TabRouteBuilder<T: TabCoordinatable> {
    public static func buildBlock(_ components: TabRouteDescriptor<T>...) -> [TabRouteDescriptor<T>] {
        components
    }

    public static func buildArray(_ components: [[TabRouteDescriptor<T>]]) -> [TabRouteDescriptor<T>] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [TabRouteDescriptor<T>]?) -> [TabRouteDescriptor<T>] {
        component ?? []
    }

    public static func buildEither(first component: [TabRouteDescriptor<T>]) -> [TabRouteDescriptor<T>] {
        component
    }

    public static func buildEither(second component: [TabRouteDescriptor<T>]) -> [TabRouteDescriptor<T>] {
        component
    }

    public static func buildExpression(_ expression: TabRouteDescriptor<T>) -> [TabRouteDescriptor<T>] {
        [expression]
    }
}
