import SwiftUI

struct GroupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var groupManager: GroupManager
    
    let groupId: String
    
    @State private var group: Group?
    @State private var members: [GroupMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditGroup = false
    @State private var showMemberManagement = false
    @State private var showDeleteConfirmation = false
    @State private var selectedTab = "main"
    
    init(groupId: String, authManager: AuthManager) {
        self.groupId = groupId
        _groupManager = StateObject(wrappedValue: GroupManager(authManager: authManager))
    }
    
    var body: some View {
        VStack {
            if let group = group {
                TabView(selection: $selectedTab) {
                    // Main Tab
                    mainTab(group: group)
                        .tag("main")
                        .tabItem {
                            Label("Group", systemImage: "person.3")
                        }
                    
                    // Admin Tab (only for admins)
                    if group.role == "admin" {
                        adminTab(group: group)
                            .tag("admin")
                            .tabItem {
                                Label("Admin", systemImage: "gear")
                            }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Failed to load group details")
                        .font(.headline)
                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Button("Try Again") {
                        Task {
                            await loadGroupAndMembers()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditGroup) {
            EditGroupView(groupId: groupId, authManager: authManager)
        }
        .sheet(isPresented: $showMemberManagement) {
            GroupMemberManagementView(groupId: groupId, authManager: authManager)
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
            await loadGroupAndMembers()
        }
        .refreshable {
            await loadGroupAndMembers()
        }
        .onChange(of: showEditGroup) { isShowing in
            if !isShowing {
                Task {
                    await loadGroupAndMembers()
                }
            }
        }
        .onChange(of: showMemberManagement) { isShowing in
            if !isShowing {
                Task {
                    await loadGroupAndMembers()
                }
            }
        }
    }
    
    private func mainTab(group: Group) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(group.name)
                        .font(.title)
                        .bold()
                    
                    if let description = group.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(group.memberCount) members", systemImage: "person.3")
                            .foregroundColor(.gray)
                        
                        if let groupType = groupManager.groupTypes.first(where: { $0.id == group.groupTypeId }) {
                            Text(groupType.groupType)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.top)
                
                // Members Grid
                VStack(alignment: .leading, spacing: 16) {
                    Text("Members")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if members.isEmpty {
                        Text("No members yet")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 12)
                        ], spacing: 12) {
                            ForEach(members.filter { $0.status == .joined }, id: \.userId) { member in
                                MemberButton(member: member)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
    }
    
    private func adminTab(group: Group) -> some View {
        List {
            Section("Group Details") {
                DetailRow(label: "Visibility", value: group.visibility == .private ? "Private" : "Public")
                DetailRow(label: "Join Method", value: group.joinMethod == .invitation ? "By Invitation" : "Direct Join")
                
                if let groupType = groupManager.groupTypes.first(where: { $0.id == group.groupTypeId }) {
                    DetailRow(label: "Type", value: groupType.groupType)
                    if let subType = groupType.subTypes.first {
                        DetailRow(label: "Sub-type", value: "\(subType.name)")
                    }
                }
                
                if let createdAt = group.createdAt {
                    DetailRow(label: "Created", value: createdAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            
            Section {
                Button("Manage Members") {
                    showMemberManagement = true
                }
                
                Button("Edit Group") {
                    showEditGroup = true
                }
                
                Button("Delete Group", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .task {
            if groupManager.groupTypes.isEmpty {
                try? await groupManager.fetchGroupTypes()
            }
        }
    }
    
    private func loadGroupAndMembers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let groupTask = groupManager.fetchGroup(id: groupId)
            async let membersTask = groupManager.fetchGroupMembers(groupId: groupId)
            
            let (fetchedGroup, fetchedMembers) = try await (groupTask, membersTask)
            group = fetchedGroup
            members = fetchedMembers
            isLoading = false
        } catch {
            print("Error loading group details: \(error)")
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