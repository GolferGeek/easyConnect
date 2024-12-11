import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var groupManager: GroupManager
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var visibility: Group.GroupVisibility = .private
    @State private var joinMethod: Group.JoinMethod = .invitation
    @State private var selectedGroupTypeId = 0
    @State private var selectedSubType: GroupManager.GroupType.SubType?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMemberManagement = false
    @State private var createdGroupId: String?
    
    init(authManager: AuthManager) {
        _groupManager = StateObject(wrappedValue: GroupManager(authManager: authManager))
    }
    
    var isFormValid: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedGroupTypeId != 0
    }
    
    var selectedGroupType: GroupManager.GroupType? {
        groupManager.groupTypes.first { $0.id == selectedGroupTypeId }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details"), footer: footerText) {
                    TextField("Group Name", text: $groupName)
                    
                    TextField("Description (Optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Group Type", selection: $selectedGroupTypeId) {
                        Text("Select a type").tag(0)
                        ForEach(groupManager.groupTypes, id: \.id) { type in
                            Text(type.groupType).tag(type.id)
                        }
                    }
                    
                    if let subTypes = selectedGroupType?.subTypes, !subTypes.isEmpty {
                        Picker("Sub Type", selection: $selectedSubType) {
                            Text("Select a sub type").tag(nil as GroupManager.GroupType.SubType?)
                            ForEach(subTypes) { subType in
                                Text(subType.name)
                                    .tag(subType as GroupManager.GroupType.SubType?)
                            }
                        }
                    }
                    
                    Picker("Visibility", selection: $visibility) {
                        Text("Private").tag(Group.GroupVisibility.private)
                        Text("Public").tag(Group.GroupVisibility.public)
                    }
                    
                    Picker("Join Method", selection: $joinMethod) {
                        Text("By Invitation").tag(Group.JoinMethod.invitation)
                        Text("Direct Join").tag(Group.JoinMethod.direct)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black.opacity(0.2))
                }
            }
            .fullScreenCover(isPresented: $showMemberManagement) {
                if let groupId = createdGroupId {
                    GroupMemberManagementView(groupId: groupId, authManager: authManager)
                }
            }
            .task {
                do {
                    try await groupManager.fetchGroupTypes()
                } catch {
                    errorMessage = "Failed to load group types: \(error.localizedDescription)"
                }
            }
            .onChange(of: selectedGroupTypeId) { _ in
                // Reset sub-type selection when group type changes
                selectedSubType = nil
            }
        }
    }
    
    private var footerText: Text {
        if visibility == .private {
            return Text("Private groups are only visible to members")
        } else {
            return Text(joinMethod == .invitation 
                ? "Members need to be invited to join"
                : "Anyone can join directly")
        }
    }
    
    private func createGroup() {
        guard let userId = authManager.currentUser?.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let groupId = try await groupManager.createGroup(
                    name: groupName,
                    description: groupDescription,
                    visibility: visibility,
                    joinMethod: joinMethod,
                    userId: userId,
                    groupTypeId: selectedGroupTypeId
                )
                
                DispatchQueue.main.async {
                    self.createdGroupId = groupId
                    self.showMemberManagement = true
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
} 
