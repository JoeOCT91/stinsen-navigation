import Foundation
import SwiftUI

struct TabCoordinatableView<T: TabCoordinatable, U: View>: View {
    @StateObject var child: TabChild

    private let coordinator: T
    private let router: TabRouter<T>
    private var views: [AnyView]
    private var customize: (AnyView) -> U

    var body: some View {
        customize(
            AnyView(
                TabView(selection: $child.activeTab) {
                    ForEach(Array(views.enumerated()), id: \.offset) { view in
                        view
                            .element
                            .tabItem {
                                coordinator.child.allItems[view.offset].tabItem(view.offset == child.activeTab)
                            }
                            .tag(view.offset)
                    }
                }
            )
        )
        .environmentObject(router)
    }
    
    init(paths: [AnyKeyPath], coordinator: T, customize: @escaping (AnyView) -> U) {
        self._child = StateObject(wrappedValue: coordinator.child)

        self.coordinator = coordinator
        
        self.router = TabRouter(coordinator: coordinator.routerStorable)
        RouterStore.shared.store(router: router)
        self.customize = customize

        if coordinator.child.allItems == nil {
            coordinator.setupAllTabs()
        }

        self.views = coordinator.child.allItems.map {
            $0.presentable.view()
        }
    }
}
