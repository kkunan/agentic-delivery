import SwiftUI

@main
struct SampleApp: App {
    var body: some Scene {
        WindowGroup {
            Text(isAdult(age: 18) ? "Adult" : "Minor")
        }
    }
}
