import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.6), .purple.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App logo/icon
                Image(systemName: "person.3.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                // App name with custom styling
                Text("EasyConnect")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                // Tagline
                Text("Connect with friends,\neffortlessly")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
                
                // Loading indicator
                ProgressView()
                    .tint(.white)
                    .padding(.top, 30)
            }
        }
        .onAppear {
            // Animate to auth screen after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    navigationState.currentScreen = .auth
                }
            }
        }
    }
} 