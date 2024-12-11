import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var groupManager: GroupManager
    @State private var showingCreateGroup = false
    @State private var showingActionSheet = false
    @State private var selectedGroup: Group?
    
    init(authManager: AuthManager) {
        _groupManager = StateObject(wrappedValue: GroupManager(authManager: authManager))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if groupManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if groupManager.groups.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No groups yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Create a group to get started")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(groupManager.groups) { group in
                            GroupRow(group: group) {
                                selectedGroup = group
                                showingActionSheet = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") {
                        authManager.signOut()
                        withAnimation {
                            navigationState.currentScreen = .auth
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView(authManager: authManager)
            }
            .confirmationDialog(
                "Group Options",
                isPresented: $showingActionSheet,
                presenting: selectedGroup
            ) { group in
                Button("Delete Group", role: .destructive) {
                    deleteGroup(group)
                }
                .disabled(!group.isOwner)
                
                Button("Cancel", role: .cancel) {}
            } message: { group in
                Text(group.name)
            }
        }
        .task {
            await groupManager.fetchGroups()
        }
    }
    
    private func deleteGroup(_ group: Group) {
        Task {
            try? await groupManager.deleteGroup(id: group.id)
        }
    }
}

struct GroupRow: View {
    let group: Group
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(group.name)
                        .font(.headline)
                    
                    Text("\(group.memberCount) members")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if group.isOwner {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            .padding(.vertical, 8)
        }
    }
} 