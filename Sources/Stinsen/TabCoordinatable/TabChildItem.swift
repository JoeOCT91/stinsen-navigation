// MARK: - TabChildItem
struct TabChildItem {
    private var _presentable: (any ViewPresentable)?
    private let presentableFactory: () -> any ViewPresentable

    let id = UUID()
    let keyPathIsEqual: (Any) -> Bool
    let tabItem: (Bool) -> AnyView
    let onTapped: (Bool) -> Void

    init(
        presentableFactory: @escaping () -> any ViewPresentable,
        keyPathIsEqual: @escaping (Any) -> Bool,
        tabItem: @escaping (Bool) -> AnyView,
        onTapped: @escaping (Bool) -> Void
    ) {
        self.presentableFactory = presentableFactory
        self.keyPathIsEqual = keyPathIsEqual
        self.tabItem = tabItem
        self.onTapped = onTapped
    }

    var presentable: any ViewPresentable {
        mutating get {
            if _presentable == nil {
                _presentable = presentableFactory()
            }
            return _presentable!
        }
    }
}

// Make TabChildItem conform to Identifiable and Equatable
extension TabChildItem: Identifiable, Equatable {
    static func == (lhs: TabChildItem, rhs: TabChildItem) -> Bool {
        lhs.id == rhs.id
    }
}