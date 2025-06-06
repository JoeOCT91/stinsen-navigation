import Foundation
import Combine
import SwiftUI

final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    // MARK: - Properties
    private let id: Int
    public let navigationStack: NavigationStack<T>
    private var cancellables = Set<AnyCancellable>()
    
    @Published var presented: Presented?

    // MARK: - Initialization
    init(id: Int, coordinator: T) {
        self.id = id
        self.navigationStack = coordinator.stack
        
        // Initial setup
        self.setupPresented(coordinator: coordinator)
        
        // Observe navigation stack changes
        navigationStack.$value
            .dropFirst()
            .sink { [weak self, coordinator] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.setupPresented(coordinator: coordinator)
                }
            }
            .store(in: &cancellables)
        
        // Handle navigation stack pops
        navigationStack.poppedTo
            .filter { [id] poppedId in poppedId <= id }
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.presented = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - View Creation Methods
    private func createNavigationView(_ view: AnyView) -> AnyView {
        AnyView(
            NavigationView(
                content: {
                    view.navigationBarHidden(true)
                }
            )
            .navigationViewStyle(StackNavigationViewStyle())
        )
    }
    
    private func createPresentedView(from presentable: ViewPresentable, coordinator: T, nextId: Int, type: PresentationType) -> Presented {
        if presentable is AnyView {
            let view = AnyView(NavigationCoordinatableView(id: nextId, coordinator: coordinator))
            
            // For modal and fullScreen presentations, wrap in NavigationView
            if type == .modal || type == .fullScreen {
                return Presented(
                    view: createNavigationView(view),
                    type: type
                )
            }
            
            return Presented(
                view: view,
                type: type
            )
        } else {
            let view = presentable.view()
            
            // For modal and fullScreen presentations, wrap in NavigationView
            if type == .modal || type == .fullScreen {
                return Presented(
                    view: createNavigationView(AnyView(view)),
                    type: type
                )
            }
            
            return Presented(
                view: AnyView(view),
                type: type
            )
        }
    }
    
    // MARK: - Public Methods
    func setupPresented(coordinator: T) {
        let value = self.navigationStack.value
        let nextId = id + 1
        
        // Only apply updates on last screen in navigation stack
        // This check ensures we only present new views when we're at the end of the stack
        guard value.count - 1 == nextId, self.presented == nil,
              let nextValue = value[safe: nextId] else {
            return
        }
        
        let presentable = nextValue.presentable
        self.presented = createPresentedView(
            from: presentable,
            coordinator: coordinator,
            nextId: nextId,
            type: nextValue.presentationType
        )
    }
}
