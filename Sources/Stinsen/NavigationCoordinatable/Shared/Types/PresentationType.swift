import Foundation
import SwiftUI

/// Defines the presentation style for navigation routes in the Stinsen coordinator system.
///
/// PresentationType determines how a navigation destination should be presented to the user,
/// affecting both the visual transition and the underlying SwiftUI presentation mechanism used.
/// Each type corresponds to a different SwiftUI presentation pattern.
///
/// ## Presentation Types
/// - **Push**: Hierarchical navigation using NavigationStack (iOS 16+)
/// - **Modal**: Sheet-style presentation that slides up from the bottom
/// - **Full Screen**: Immersive full-screen presentation (iOS only)
///
/// ## Usage in Routes
/// ```swift
/// final class HomeCoordinator: NavigationCoordinatable {
///     @Route(.push) var details = makeDetails        // Push navigation
///     @Route(.modal) var settings = makeSettings     // Modal sheet
///     @Route(.fullScreen) var camera = makeCamera    // Full-screen cover
/// }
/// ```
///
/// ## SwiftUI Mapping
/// - `.push` → `NavigationStack` with `navigationDestination`
/// - `.modal` → `.sheet()` modifier
/// - `.fullScreen` → `.fullScreenCover()` modifier (iOS only)
public enum PresentationType {
    /// Modal presentation using SwiftUI's sheet mechanism.
    ///
    /// Presents content in a sheet that slides up from the bottom of the screen.
    /// Users can dismiss by swiping down or using the dismiss button. Ideal for
    /// settings, forms, or secondary content that doesn't require full attention.
    ///
    /// ## Characteristics
    /// - Slides up from bottom
    /// - Partially covers underlying content
    /// - Dismissible via swipe gesture
    /// - Maintains context of parent view
    case modal

    /// Push navigation using SwiftUI's NavigationStack.
    ///
    /// Adds content to the navigation hierarchy with a slide-in transition.
    /// Provides automatic back button and supports swipe-to-go-back gesture.
    /// This is the standard pattern for hierarchical navigation flows.
    ///
    /// ## Characteristics
    /// - Slides in from right (LTR) or left (RTL)
    /// - Automatic back button in navigation bar
    /// - Swipe-to-go-back gesture support
    /// - Maintains navigation breadcrumb
    case push

    /// Full-screen presentation covering the entire screen (iOS only).
    ///
    /// Presents content that completely covers the underlying interface,
    /// creating an immersive experience. Typically used for camera interfaces,
    /// media viewers, or other content requiring full user attention.
    ///
    /// ## Characteristics
    /// - Covers entire screen
    /// - No automatic dismiss gesture
    /// - Requires explicit dismiss action
    /// - iOS only (gracefully handled on other platforms)
    case fullScreen

    /// Indicates whether this presentation type is modal.
    ///
    /// Used by PresentationHelper to filter navigation stack items and determine
    /// which items should be presented using SwiftUI's `.sheet()` modifier.
    ///
    /// - Returns: `true` for `.modal` type, `false` for all others
    var isModal: Bool {
        switch self {
        case .modal:
            return true
        default:
            return false
        }
    }

    /// Indicates whether this presentation type is push navigation.
    ///
    /// Used by PresentationHelper to filter navigation stack items and determine
    /// which items should be added to the NavigationStack path for hierarchical navigation.
    ///
    /// - Returns: `true` for `.push` type, `false` for all others
    var isPush: Bool {
        switch self {
        case .push:
            return true
        default:
            return false
        }
    }

    /// Indicates whether this presentation type is full-screen.
    ///
    /// Used by PresentationHelper to filter navigation stack items and determine
    /// which items should be presented using SwiftUI's `.fullScreenCover()` modifier.
    /// Note that full-screen presentation is only available on iOS.
    ///
    /// - Returns: `true` for `.fullScreen` type, `false` for all others
    var isFullScreen: Bool {
        switch self {
        case .fullScreen:
            return true
        default:
            return false
        }
    }
}
