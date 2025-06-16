import Foundation
import SwiftUI

/// A fully type-safe wrapper for ViewPresentable that avoids all type erasure.
///
/// This version maintains complete type safety throughout the entire pipeline,
/// using generics to preserve exact types without any type erasure.
public struct TypeSafePresentableWrapper<P: ViewPresentable> {
    /// The strongly-typed presentable instance
    private let presentable: P

    /// Initializes a wrapper with a specific presentable type.
    ///
    /// This initializer captures the presentable's exact type without any erasure.
    ///
    /// - Parameter presentable: The specific presentable to wrap
    public init(_ presentable: P) {
        self.presentable = presentable
    }

    /// Returns the strongly-typed presentable.
    public var wrappedPresentable: P {
        return presentable
    }

    /// Creates the view using the preserved exact type information.
    ///
    /// This method returns the exact view type without any type erasure,
    /// maintaining optimal SwiftUI performance and type safety.
    ///
    /// - Returns: The presentable's view with exact type preservation
    public func createView() -> P.PresentedView {
        return presentable.view()
    }

    /// Creates a view builder that can be used in SwiftUI contexts.
    ///
    /// This provides maximum flexibility for view composition while
    /// maintaining complete type safety.
    @ViewBuilder
    public func buildView() -> some View {
        presentable.view()
    }
}

/// A generic collection wrapper that maintains type safety for homogeneous collections.
///
/// This allows storing collections of the same presentable type without type erasure.
public struct TypeSafePresentableCollection<P: ViewPresentable> {
    /// Array of strongly-typed presentable wrappers
    private let wrappers: [TypeSafePresentableWrapper<P>]

    /// Initializes a collection with an array of presentables.
    public init(_ presentables: [P]) {
        wrappers = presentables.map { TypeSafePresentableWrapper($0) }
    }

    /// Access wrapper by index
    public subscript(index: Int) -> TypeSafePresentableWrapper<P>? {
        guard index >= 0, index < wrappers.count else { return nil }
        return wrappers[index]
    }

    /// Number of items in the collection
    public var count: Int {
        return wrappers.count
    }

    /// Iterate over wrappers
    public func forEach(_ body: (TypeSafePresentableWrapper<P>) -> Void) {
        wrappers.forEach(body)
    }
}

/// A heterogeneous collection wrapper that uses generics to avoid type erasure.
///
/// This uses associated type containers to maintain type safety even with
/// different presentable types in the same conceptual collection.
public protocol TypeSafePresentableContainer {
    associatedtype Content: View

    @ViewBuilder
    func buildContent() -> Content
}

/// Implementation of TypeSafePresentableContainer for single presentables.
public struct SinglePresentableContainer<P: ViewPresentable>: TypeSafePresentableContainer {
    private let wrapper: TypeSafePresentableWrapper<P>

    public init(_ presentable: P) {
        wrapper = TypeSafePresentableWrapper(presentable)
    }

    @ViewBuilder
    public func buildContent() -> some View {
        wrapper.buildView()
    }
}

/// A view builder that can handle multiple different presentable types.
public struct TypeSafeNavigationContent<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
    }
}

// MARK: - Builder Functions

/// Creates a type-safe navigation content builder.
@ViewBuilder
public func buildNavigationContent<P: ViewPresentable>(
    from presentable: P
) -> some View {
    TypeSafePresentableWrapper(presentable).buildView()
}

/// Creates a type-safe navigation content builder from multiple presentables.
@ViewBuilder
public func buildNavigationContent<P1: ViewPresentable, P2: ViewPresentable>(
    _ presentable1: P1,
    _ presentable2: P2
) -> some View {
    VStack {
        TypeSafePresentableWrapper(presentable1).buildView()
        TypeSafePresentableWrapper(presentable2).buildView()
    }
}

// MARK: - Legacy Compatibility (for gradual migration)

/// Legacy type-erased wrapper for backward compatibility.
///
/// Use this only when absolutely necessary for interfacing with
/// existing APIs that require type erasure.
@available(*, deprecated, message: "Use TypeSafePresentableWrapper<P> instead") public struct LegacyPresentableWrapper {
    private let _createView: () -> AnyView

    public init<P: ViewPresentable>(_ presentable: P) {
        _createView = { AnyView(presentable.view()) }
    }

    public func createView() -> AnyView {
        return _createView()
    }
}
