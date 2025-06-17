import SwiftUI

struct Presented<Content: View> {
    let view: Content
    let type: PresentationType

    init(view: Content, type: PresentationType) {
        self.view = view
        self.type = type
    }
}
