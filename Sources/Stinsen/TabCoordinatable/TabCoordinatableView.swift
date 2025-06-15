import Foundation
import SwiftUI

// MARK: - Native TabCoordinatableView

struct TabCoordinatableView<T: TabCoordinatable, U: View>: View {
    @ObservedObject private var child: TabChild<T>

    private let coordinator: T
    private let router: TabRouter<T>
    private let customize: (AnyView) -> U

    // MARK: - Initialization

    init(coordinator: T, customize: @escaping (AnyView) -> U) {
        self.coordinator = coordinator
        router = TabRouter(coordinator: coordinator.routerStorable)
        self.customize = customize
        _child = ObservedObject(wrappedValue: coordinator.child)

        RouterStore.shared.store(router: router)
    }

    var body: some View {
        // Apply customize to the actual TabView content, not the wrapper
        customize(AnyView(nativeTabView))
            .environmentObject(router)
            .task {
                // Eagerly initialize tabs for immediate navigation availability
                await coordinator.initializeTabsAsync()
            }
    }

    // MARK: - Pure Native TabView

    private var nativeTabView: some View {
        let tabBinding = Binding(
            get: { child.activeTab },
            set: { child.activeTab = $0 }
        )

        return TabView(selection: tabBinding) {
            ForEach(child.allItems.indices, id: \.self) { index in
                if let item = child.item(at: index) {
                    // Use the wrapper's createView method to get properly typed AnyView
                    TabItemView(item: item, isActive: child.isTabActive(at: index))
                        .tag(index)
                }
            }
        }
    }
}

// MARK: - TabItemView Wrapper

/// A wrapper view that properly handles the tab item presentation with type safety.
/// This eliminates the need for AnyView in the ForEach while maintaining proper typing.
struct TabItemView: View {
    let item: AnyTabChildItem
    let isActive: Bool

    var body: some View {
        // Get the actual view content using the wrapper's createView method
        TabPresentableWrapper(presentable: item.presentable).createView()
            .tabItem {
                // Use the native tab item directly
                item.tabItem(isActive)
            }
    }
}

// MARK: - TabPresentableWrapper

/// A type-safe wrapper for ViewPresentable in tab context that preserves associated type information.
/// Similar to TypeSafePresentableWrapper but specifically designed for tab presentations.
struct TabPresentableWrapper {
    /// Type-safe view creation closure that preserves the original associated type
    private let _createView: () -> AnyView

    /// Initializes a wrapper with a type-erased presentable.
    /// Since we receive any ViewPresentable, we create the closure directly.
    init(presentable: any ViewPresentable) {
        _createView = { AnyView(presentable.view()) }
    }

    /// Creates the view using the preserved type information.
    /// This method uses the captured closure to create the view.
    func createView() -> AnyView {
        return _createView()
    }
}
