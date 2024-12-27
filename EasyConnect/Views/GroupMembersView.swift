import SwiftUI

struct GroupMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var groupManager: GroupManager
    
    let groupId: String
    
    @State private var members: [GroupMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showInviteSheet = false
    
    init(groupId: String, authManager: AuthManager) {
        self.groupId = groupId
        _groupManager = StateObject(wrappedValue: GroupManager(authManager: authManager))
    }
    
    var body: some View {
        List {
            if !members.isEmpty {
                Section("Active Members (\(members.filter { $0.status == .joined }.count))") {
                    ForEach(members.filter { $0.status == .joined }, id: \.userId) { member in
                        GroupMemberRow(member: member)
                    }
                }
                
                if !members.filter({ $0.status == .invited }).isEmpty {
                    Section("Pending Invites (\(members.filter { $0.status == .invited }.count))") {
                        ForEach(members.filter { $0.status == .invited }, id: \.userId) { member in
                            GroupMemberRow(member: member) {
                                resendInvite(to: member)
                            }
                        }
                    }
                }
                
                if !members.filter({ $0.status == .declined }).isEmpty {
                    Section("Declined Invites") {
                        ForEach(members.filter { $0.status == .declined }, id: \.userId) { member in
                            GroupMemberRow(member: member) {
                                resendInvite(to: member)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showInviteSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteToGroupView(groupId: groupId, authManager: authManager)
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.2))
            }
        }
        .task {
            await loadMembers()
        }
        .refreshable {
            await loadMembers()
        }
    }
    
    private func loadMembers() async {
        isLoading = true
        do {
            members = try await groupManager.fetchGroupMembers(groupId: groupId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func resendInvite(to member: GroupMember) {
        Task {
            do {
                try await groupManager.resendInvite(groupId: groupId, userId: member.userId)
                await loadMembers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
} 