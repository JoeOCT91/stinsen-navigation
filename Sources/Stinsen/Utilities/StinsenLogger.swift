import Foundation
import OSLog

/// Centralized logging system for Stinsen navigation framework
/// Provides structured logging with different categories and levels
public enum StinsenLogger {
    // MARK: - Log Categories

    /// Navigation stack operations and state changes
    public static let navigation = Logger(subsystem: "com.stinsen.navigation", category: "Navigation")

    /// Coordinator lifecycle and management
    public static let coordinator = Logger(subsystem: "com.stinsen.navigation", category: "Coordinator")

    /// Route operations and transitions
    public static let routing = Logger(subsystem: "com.stinsen.navigation", category: "Routing")

    /// Presentation layer operations (modals, sheets, etc.)
    public static let presentation = Logger(subsystem: "com.stinsen.navigation", category: "Presentation")

    /// General framework operations
    public static let general = Logger(subsystem: "com.stinsen.navigation", category: "General")

    // MARK: - Convenience Methods

    /// Log navigation stack state changes
    public static func logStackState(
        itemCount: Int,
        items: [(index: Int, type: String, presentable: String)],
        modalItem: String? = nil,
        fullScreenItem: String? = nil,
        pushedCoordinator: String? = nil,
        childCoordinators: [String] = [],
        pushPathCount: Int,
        coordinatorCounts: (total: Int, navigation: Int, child: Int)
    ) {
        var message = "Stack changed: \(itemCount) items\n"

        // Add stack items
        for item in items {
            message += "  \(item.index): \(item.type) - \(item.presentable)\n"
        }

        // Add modal info
        if let modal = modalItem {
            message += "📱 Modal: \(modal)\n"
        }

        // Add full-screen info
        if let fullScreen = fullScreenItem {
            message += "🖥️ Full-screen: \(fullScreen)\n"
        }

        // Add pushed coordinator info
        if let coordinator = pushedCoordinator {
            message += "🎯 Pushed NavigationCoordinator: \(coordinator)\n"
        }

        // Add child coordinators info
        if !childCoordinators.isEmpty {
            message += "👶 Child coordinators: \(childCoordinators.joined(separator: ", "))\n"
        }

        // Add push path summary
        message +=
            "🛤️ Push path: \(pushPathCount) items (coordinators: \(coordinatorCounts.total) total, \(coordinatorCounts.navigation) navigation, \(coordinatorCounts.child) child)"

        navigation.info("\(message)")
    }

    /// Log coordinator lifecycle events
    public static func logCoordinatorLifecycle(_: String, coordinator _: String, details _: String? = nil) {
//        if let details = details {
//            coordinator.info("🔄 \(event): \(coordinator) - \(details)")
//        } else {
//            coordinator.info("🔄 \(event): \(coordinator)")
//        }
    }

    /// Log route operations
    public static func logRoute(_ operation: String, route: String, details: String? = nil) {
        if let details = details {
            routing.info("🛣️ \(operation): \(route) - \(details)")
        } else {
            routing.info("🛣️ \(operation): \(route)")
        }
    }

    /// Log presentation operations
    public static func logPresentation(_ operation: String, type: String, details: String? = nil) {
        if let details = details {
            presentation.info("🎭 \(operation): \(type) - \(details)")
        } else {
            presentation.info("🎭 \(operation): \(type)")
        }
    }

    /// Log navigation operations
    public static func logNavigation(_ operation: String, target: Int? = nil, stackSize: Int? = nil, details: String? = nil) {
        var message = "📤 \(operation)"

        if let target = target, let stackSize = stackSize {
            message += ": target=\(target), current stack size=\(stackSize)"
        }

        if let details = details {
            message += " - \(details)"
        }

        navigation.info("\(message)")
    }

    /// Log navigation operations with custom message
    public static func logNavigation(_ operation: String, operation details: String) {
        navigation.info("📤 \(operation): \(details)")
    }

    /// Log errors with context
    public static func logError(_ error: String, category: LogCategory = .general, context: String? = nil) {
        let logger = loggerFor(category)
        if let context = context {
            logger.error("❌ \(error) - Context: \(context)")
        } else {
            logger.error("❌ \(error)")
        }
    }

    /// Log warnings with context
    public static func logWarning(_ warning: String, category: LogCategory = .general, context: String? = nil) {
        let logger = loggerFor(category)
        if let context = context {
            logger.warning("⚠️ \(warning) - Context: \(context)")
        } else {
            logger.warning("⚠️ \(warning)")
        }
    }

    /// Log debug information
    public static func logDebug(_ message: String, category: LogCategory = .general, context: String? = nil) {
        let logger = loggerFor(category)
        if let context = context {
            logger.debug("🐛 \(message) - Context: \(context)")
        } else {
            logger.debug("🐛 \(message)")
        }
    }

    // MARK: - Private Helpers

    private static func loggerFor(_ category: LogCategory) -> Logger {
        switch category {
        case .navigation: return navigation
        case .coordinator: return coordinator
        case .routing: return routing
        case .presentation: return presentation
        case .general: return general
        }
    }
}

// MARK: - Log Category Enum

public enum LogCategory {
    case navigation
    case coordinator
    case routing
    case presentation
    case general
}
