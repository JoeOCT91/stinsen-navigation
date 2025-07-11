import Foundation
import SwiftUI
import Combine

struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    private let id: Int
    private let router: NavigationRouter<T>
    @StateObject private var presentationHelper: PresentationHelper<T>
    @ObservedObject var root: NavigationRoot
    
    var start: AnyView?

    var body: some View {
        commonView
            .environmentObject(router)
            .background(
                Color
                    .clear
                    .fullScreenCover(isPresented: Binding<Bool>.init(get: { () -> Bool in
                        return presentationHelper.presented?.type.isFullScreen == true
                    }, set: { _ in
                        self.coordinator.appear(self.id)
                    }), onDismiss: {
                        self.coordinator.stack.dismissalAction[id]?()
                        self.coordinator.stack.dismissalAction[id] = nil
                    }, content: { () -> AnyView in
                        return { () -> AnyView in
                            if let view = presentationHelper.presented?.view {
                                return AnyView(view)
                            } else {
                                return AnyView(EmptyView())
                            }
                        }()
                    })
                    .environmentObject(router)
            )
    }
    
    @ViewBuilder
    var commonView: some View {
        (id == -1 ? AnyView(self.coordinator.customize(AnyView(root.item.child.view()))) : AnyView(self.start!))
            .background(
                NavigationLink(
                    destination: { () -> AnyView in
                        if let view = presentationHelper.presented?.view {
                            return AnyView(view.onDisappear {
                                self.coordinator.stack.dismissalAction[id]?()
                                self.coordinator.stack.dismissalAction[id] = nil
                            })
                        } else {
                            return AnyView(EmptyView())
                        }
                    }(),
                    isActive: Binding<Bool>.init(get: { () -> Bool in
                        return presentationHelper.presented?.type.isPush == true
                    }, set: { _ in
                        self.coordinator.appear(self.id)
                    }),
                    label: {
                        EmptyView()
                    }
                )
                .hidden()
            )
            .sheet(isPresented: Binding<Bool>.init(get: { () -> Bool in
                return presentationHelper.presented?.type.isModal == true
            }, set: { _ in
                self.coordinator.appear(self.id)
            }), onDismiss: {
                self.coordinator.stack.dismissalAction[id]?()
                self.coordinator.stack.dismissalAction[id] = nil
            }, content: { () -> AnyView in
                return { () -> AnyView in
                    if let view = presentationHelper.presented?.view {
                        return AnyView(view)
                    } else {
                        return AnyView(EmptyView())
                    }
                }()
            })
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        
        _presentationHelper = StateObject(
            wrappedValue: PresentationHelper(
                id: id,
                coordinator: coordinator
            )
        )
        
        self.router = NavigationRouter(
            id: id,
            coordinator: coordinator.routerStorable
        )
        
        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }
        
        self.root = coordinator.stack.root

        RouterStore.shared.store(router: router)
        
        if let presentation = coordinator.stack.value[safe: id] {
            if let view = presentation.presentable as? AnyView {
                self.start = view
            } else {
                fatalError("Can only show views")
            }
        } else if id == -1 {
            self.start = nil
        } else {
            fatalError()
        }
    }
}
