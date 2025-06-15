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
        self.router = TabRouter(coordinator: coordinator.routerStorable)
        self.customize = customize
        self._child = ObservedObject(wrappedValue: coordinator.child)

        RouterStore.shared.store(router: router)
    }

    var body: some View {
        // Pure native TabView - no customizations, but still apply customize function
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
                    // Get the actual view content
                    AnyView(item.presentable.view())
                        .tabItem {
                            // Use the native tab item directly
                            item.tabItem(child.isTabActive(at: index))
                        }
                        .tag(index)
                }
            }
        }
    }
}
