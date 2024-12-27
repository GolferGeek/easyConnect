import SwiftUI

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var groupManager: GroupManager
    
    let groupId: String
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var visibility: Group.GroupVisibility = .private
    @State private var joinMethod: Group.JoinMethod = .invitation
    @State private var selectedGroupTypeId = 0
    @State private var selectedSubType: GroupManager.GroupType.SubType?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMemberManagement = false
    @State private var group: Group?
    @State private var showMembersSheet = false
    
    init(groupId: String, authManager: AuthManager) {
        self.groupId = groupId
        _groupManager = StateObject(wrappedValue: GroupManager(authManager: authManager))
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
                
                Section {
                    Button("Manage Members") {
                        showMemberManagement = true
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGroup()
                    }
                    .disabled(isLoading)
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
            .sheet(isPresented: $showMemberManagement) {
                GroupMemberManagementView(groupId: groupId, authManager: authManager)
            }
            .sheet(isPresented: $showMembersSheet) {
                GroupMembersView(groupId: groupId, authManager: authManager)
            }
            .task {
                do {
                    try await groupManager.fetchGroupTypes()
                    let fetchedGroup = try await groupManager.fetchGroup(id: groupId)
                    
                    // Update all the form fields
                    groupName = fetchedGroup.name
                    groupDescription = fetchedGroup.description ?? ""
                    visibility = fetchedGroup.visibility
                    joinMethod = fetchedGroup.joinMethod
                    group = fetchedGroup
                    
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .onChange(of: selectedGroupTypeId) { _ in
                selectedSubType = nil
            }
        }
    }
    
    private var selectedGroupType: GroupManager.GroupType? {
        groupManager.groupTypes.first { $0.id == selectedGroupTypeId }
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
    
    private func saveGroup() {
        guard let userId = authManager.currentUser?.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await groupManager.updateGroup(
                    id: groupId,
                    name: groupName,
                    description: groupDescription.isEmpty ? nil : groupDescription,
                    visibility: visibility,
                    joinMethod: joinMethod,
                    groupTypeId: selectedGroupTypeId
                )
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.dismiss()
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