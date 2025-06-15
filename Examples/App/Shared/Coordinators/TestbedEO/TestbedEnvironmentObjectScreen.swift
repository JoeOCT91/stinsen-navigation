import Foundation
import SwiftUI
import Stinsen

struct TestbedEnvironmentObjectScreen: View {
    @EnvironmentObject var testbed: TestbedEnvironmentObjectCoordinator.Router
    @State var text: String = ""
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    Text("Number in coordinator stack: " + String(testbed.id))
                    TextField("Textfield", text: $text)
                    
                    RoundedButton("Modal screen") {
                        //                    testbed.route(to: \.modalScreen)
                    }
                    
                    RoundedButton("Push screen") {
                        testbed.route(to: \.pushScreen)
                    }
                    
                    RoundedButton("Cover screen") {
                        
                    }
                    
                    RoundedButton("Modal coordinator") {
                        //                    testbed.route(to: \.modalCoordinator)
                    }
                    
                    RoundedButton("Push coordinator") {
                        //                    testbed.route(to: \.pushCoordinator)
                    }
                    /*
                     if #available(iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
                     RoundedButton("Cover coordinator") {
                     testbed.route(to: .coverCoordinator)
                     }
                     }
                     */
                    RoundedButton("Dismiss me!") {
                        testbed.dismissCoordinator {
                            print("bye!")
                        }
                    }
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
    }
}
