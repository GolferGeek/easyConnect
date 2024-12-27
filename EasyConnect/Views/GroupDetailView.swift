import SwiftUI

struct GroupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var groupManager: GroupManager
    
    let groupId: String
    
    @State private var group: Group?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditGroup = false
    @State private var showMemberManagement = false
    @State private var showDeleteConfirmation = false
    @State private var showMembersSheet = false
    
    init(groupId: String, authManager: AuthManager) {
        self.groupId = groupId
        _groupManager = StateObject(wrappedValue: GroupManager(authManager: authManager))
    }
    
    var body: some View {
        VStack {
            if let group = group {
                List {
                    Section("Details") {
                        DetailRow(label: "Name", value: group.name)
                        if let description = group.description {
                            DetailRow(label: "Description", value: description)
                        }
                        DetailRow(label: "Visibility", value: group.visibility == .private ? "Private" : "Public")
                        DetailRow(label: "Join Method", value: group.joinMethod == .invitation ? "By Invitation" : "Direct Join")
                        DetailRow(label: "Members", value: "\(group.memberCount)")
                        if let createdAt = group.createdAt {
                            DetailRow(label: "Created", value: createdAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    
                    Section {
                        Button("Manage Members") {
                            showMemberManagement = true
                        }
                        
                        if group.role == "admin" {
                            Button("Edit Group") {
                                showEditGroup = true
                            }
                            
                            Button("Delete Group", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                        }
                    }
                }
                .navigationTitle(group.name)
                .navigationBarTitleDisplayMode(.inline)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Text("Failed to load group details")
                    .foregroundColor(.red)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditGroup) {
            EditGroupView(groupId: groupId, authManager: authManager)
        }
        .sheet(isPresented: $showMemberManagement) {
            GroupMembersView(groupId: groupId, authManager: authManager)
        }
        .alert("Delete Group", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGroup()
            }
        } message: {
            Text("Are you sure you want to delete this group? This action cannot be undone.")
        }
        .task {
            await loadGroup()
        }
        .refreshable {
            await loadGroup()
        }
    }
    
    private func loadGroup() async {
        isLoading = true
        errorMessage = nil
        
        do {
            group = try await groupManager.fetchGroup(id: groupId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func deleteGroup() {
        Task {
            do {
                try await groupManager.deleteGroup(id: groupId)
                DispatchQueue.main.async {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
        }
    }
} 