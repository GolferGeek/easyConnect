import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        ZStack {
            switch navigationState.currentScreen {
            case .splash:
                SplashView()
            case .auth:
                AuthView()
            case .home:
                HomeView(authManager: authManager)
            }
        }
    }
} 