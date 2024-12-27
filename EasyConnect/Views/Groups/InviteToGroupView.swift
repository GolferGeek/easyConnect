import SwiftUI

struct InviteToGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupManager: GroupManager
    
    let groupId: String
    
    @State private var emailInput = ""
    @State private var emails: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showExistingMembers = false
    @State private var selectedMembers: Set<String> = []
    
    init(groupId: String, authManager: AuthManager) {
        self.groupId = groupId
        _groupManager = StateObject(wrappedValue: GroupManager(authManager: authManager))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Show existing members", isOn: $showExistingMembers)
                }
                
                if showExistingMembers {
                    Section("Select Members") {
                        if groupManager.isLoading {
                            ProgressView()
                        } else {
                            ForEach(groupManager.allUsers, id: \.id) { member in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(member.name)
                                            .font(.headline)
                                        Text(member.email)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedMembers.contains(member.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedMembers.contains(member.id) {
                                        selectedMembers.remove(member.id)
                                    } else {
                                        selectedMembers.insert(member.id)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section("Add Email Addresses") {
                        HStack {
                            TextField("Email", text: $emailInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                            
                            Button("Add") {
                                addEmail()
                            }
                            .disabled(emailInput.isEmpty || !emailInput.contains("@"))
                        }
                        
                        ForEach(emails, id: \.self) { email in
                            Text(email)
                        }
                        .onDelete { indexSet in
                            emails.remove(atOffsets: indexSet)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Invite Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendInvites()
                    }
                    .disabled(isLoading || (emails.isEmpty && selectedMembers.isEmpty))
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
            .task {
                if showExistingMembers {
                    await loadUsers()
                }
            }
            .onChange(of: showExistingMembers) { newValue in
                if newValue {
                    Task {
                        await loadUsers()
                    }
                }
            }
        }
    }
    
    private func addEmail() {
        let trimmedEmail = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty && !emails.contains(trimmedEmail) {
            emails.append(trimmedEmail)
            emailInput = ""
        }
    }
    
    private func loadUsers() async {
        do {
            try await groupManager.fetchAllUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func sendInvites() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if !emails.isEmpty {
                    let results = try await groupManager.inviteMembers(groupId: groupId, emails: emails)
                    // Handle results if needed
                }
                
                if !selectedMembers.isEmpty {
                    let members = groupManager.allUsers.filter { selectedMembers.contains($0.id) }
                    try await groupManager.addMembers(groupId: groupId, members: members)
                }
                
                DispatchQueue.main.async {
                    isLoading = false
                    dismiss()
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