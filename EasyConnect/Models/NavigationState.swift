import Foundation

class NavigationState: ObservableObject {
    enum Screen {
        case splash
        case auth
        case home
    }
    
    @Published var currentScreen: Screen = .splash
} 