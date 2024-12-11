import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://jvhxlvfhtbqcjyisxtlw.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2aHhsdmZodGJxY2p5aXN4dGx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMyNDIzNjAsImV4cCI6MjA0ODgxODM2MH0.4Z5k-odLwiZuwEDWf6_PiY2NQDIx12gUEUL4mOOm1KM"
        )
    }

} 
