import Foundation

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let supabase = SupabaseManager.shared
    
    struct User {
        let id: String
        let email: String
    }
    
    func signIn(email: String, password: String) async throws {
        let auth = supabase.client.auth
        let authResponse = try await auth.signIn(
            email: email,
            password: password
        )
        
            DispatchQueue.main.async {
                self.currentUser = User(
                    id: authResponse.user.id.uuidString,
                    email: authResponse.user.email ?? ""
                )
                self.isAuthenticated = true
            }
 
    }
    
    func signUp(email: String, password: String) async throws {
        let auth = supabase.client.auth
        let session = try await auth.signUp(
            email: email,
            password: password
        )
        

            DispatchQueue.main.async {
                self.currentUser = User(
                    id: session.user.id.uuidString,
                    email: session.user.email ?? ""
                )
                self.isAuthenticated = true
            }

    }
    
    func signOut() {
        Task {
            do {
                let auth = supabase.client.auth
                try await auth.signOut()
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            } catch {
                print("Error signing out: \(error)")
            }
        }
    }
} 
