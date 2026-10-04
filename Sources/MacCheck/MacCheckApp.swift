import SwiftUI

@main
struct MacCheckApp: App {
    @StateObject private var model = DiagnosticsModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 640)
        }
        .windowStyle(.titleBar)
    }
}
