# ChildCoordinatable

A protocol that defines a coordinator capable of being used as a child of `NavigationCoordinatable`.

## Overview

`ChildCoordinatable` provides a specialized coordinator that shares the navigation stack with its parent but can only control the stack to its own root, not beyond it. This maintains encapsulation while allowing child coordinators to manage their own navigation hierarchy.

## Key Features

- **Shared Stack**: The navigation stack is shared from the parent coordinator
- **Limited Control**: Child can only control stack elements from its root downward  
- **Type Safety**: Maintains strong typing with associated types
- **Customization**: Supports view customization like NavigationCoordinatable

## Stack Control Rules

The child coordinator can:
- Push new items onto the stack
- Pop items back to its root
- Focus on items within its scope
- Customize views within its hierarchy

The child coordinator cannot:
- Pop beyond its root item
- Modify parent's navigation items
- Dismiss the parent coordinator directly

## Basic Usage

### 1. Define Your Child Coordinator

```swift
final class DetailCoordinator: ChildCoordinatable {
    typealias Parent = MainCoordinator
    weak var parent: MainCoordinator?
    
    private(set) var root: NavigationStackItem
    
    init(root: NavigationStackItem) {
        self.root = root
    }
    
    func customize(_ view: PresentedView) -> some View {
        view
            .tint(.blue)
            .navigationBarTitleDisplayMode(.inline)
    }
}
```

### 2. Create Child from Parent Coordinator

```swift
final class MainCoordinator: NavigationCoordinatable {
    var stack = NavigationStack(initial: \.home)
    
    @Route(.push) var detail = makeDetailCoordinator
    
    func makeDetailCoordinator() -> DetailCoordinator {
        let coordinator = DetailCoordinator(root: /* appropriate root item */)
        coordinator.parent = self
        return coordinator
    }
}
```

### 3. Use Child Coordinator Methods

```swift
// In your child coordinator
func navigateToSubview() {
    parent?.route(to: \.someView)
}

func returnToRoot() {
    popToChildRoot {
        print("Returned to child root")
    }
}

func checkControl(of item: NavigationStackItem) -> Bool {
    return canControl(item)
}
```

## Available Methods

### Navigation Control

- `popToChildRoot(_:)` - Pops back to this child's root
- `focusWithinScope(_:)` - Focuses on item within child's scope
- `canControl(_:)` - Checks if item is within child's control

### Stack Information

- `stack` - The shared navigation stack (read-only)
- `root` - The child's root boundary item
- `rootIndex` - Index of root in stack
- `controlledStack` - Stack items under child's control

### Routing (Delegated to Parent)

- `route(to:_:)` - Navigate using parent's routes
- Various overloads for different route types

## Best Practices

1. **Always use weak references** for the parent to avoid retain cycles
2. **Set the parent reference** immediately after creating the child coordinator
3. **Use the root item** to define clear boundaries for child control
4. **Leverage the routing methods** to maintain consistency with parent navigation
5. **Customize views appropriately** within the child's scope

## Example Implementation

See the main `ChildCoordinatable.swift` file for the complete protocol definition and default implementations. 