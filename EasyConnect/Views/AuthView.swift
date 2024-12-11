import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var authManager: AuthManager
    @State private var isLogin = true
    @State private var email = "golfergeek@gmail.com"  // Default for development
    @State private var password = "GolferGeek01!"      // Default for development
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.6), .purple.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Logo
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    // Title
                    Text(isLogin ? "Welcome Back!" : "Create Account")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Form
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: handleAuth) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isLogin ? "Sign In" : "Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .disabled(isLoading)
                    }
                    .padding(.horizontal)
                    
                    // Toggle between login and signup
                    Button {
                        withAnimation {
                            isLogin.toggle()
                            // Reset error message when switching modes
                            errorMessage = nil
                        }
                    } label: {
                        Text(isLogin ? "Need an account? Sign up" : "Already have an account? Sign in")
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
        }
    }
    
    private func handleAuth() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isLogin {
                    try await authManager.signIn(email: email, password: password)
                } else {
                    try await authManager.signUp(email: email, password: password)
                }
                
                withAnimation {
                    navigationState.currentScreen = .home
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
} 