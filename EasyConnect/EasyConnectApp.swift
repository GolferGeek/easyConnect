import SwiftUI

@main
struct EasyConnectApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var navigationState = NavigationState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(navigationState)
        }
    }
} 