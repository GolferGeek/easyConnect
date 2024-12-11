import SwiftUI
import Contacts
import ContactsUI

struct GroupMemberManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupManager: GroupManager
    
    let groupId: String
    
    @State private var selectedMembers: Set<Member> = []
    @State private var showingContactPicker = false
    @State private var newEmail = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    init(groupId: String, authManager: AuthManager) {
        self.groupId = groupId
        _groupManager = StateObject(wrappedValue: GroupManager(authManager: authManager))
    }
    
    var filteredExistingMembers: [Member] {
        if searchText.isEmpty {
            return groupManager.existingMembers
        }
        return groupManager.existingMembers.filter { member in
            member.name.localizedCaseInsensitiveContains(searchText) ||
            member.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("Search", text: $searchText)
                        .textInputAutocapitalization(.never)
                }
                
                Section(header: Text("Add Members from Existing Groups")) {
                    if filteredExistingMembers.isEmpty {
                        Text("No matching members found")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(filteredExistingMembers) { member in
                            MemberRow(member: member, isSelected: selectedMembers.contains(member)) {
                                if selectedMembers.contains(member) {
                                    selectedMembers.remove(member)
                                } else {
                                    selectedMembers.insert(member)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Add from Contacts")) {
                    Button {
                        showingContactPicker = true
                    } label: {
                        HStack {
                            Text("Select from Contacts")
                            Spacer()
                            Text("\(selectedMembers.filter { $0.source == .contacts }.count) selected")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("Add by Email")) {
                    HStack {
                        TextField("Email Address", text: $newEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        
                        Button("Add") {
                            addManualEmail()
                        }
                        .disabled(newEmail.isEmpty || !newEmail.isValidEmail())
                    }
                }
                
                if !selectedMembers.isEmpty {
                    Section("Selected Members (\(selectedMembers.count))") {
                        ForEach(Array(selectedMembers)) { member in
                            HStack {
                                Text(member.name)
                                Spacer()
                                Text(member.email)
                                    .foregroundColor(.gray)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    selectedMembers.remove(member)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
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
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMembers()
                    }
                    .disabled(selectedMembers.isEmpty || isLoading)
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
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerView(selectedMembers: $selectedMembers)
            }
            .task {
                do {
                    try await groupManager.fetchExistingMembers()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func addManualEmail() {
        let member = Member(
            id: UUID().uuidString,
            email: newEmail,
            name: newEmail,
            source: .manual,
            isSelected: true
        )
        selectedMembers.insert(member)
        newEmail = ""
    }
    
    private func addMembers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await groupManager.addMembers(groupId: groupId, members: Array(selectedMembers))
                DispatchQueue.main.async {
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

struct MemberRow: View {
    let member: Member
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(member.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

struct ContactPickerView: UIViewControllerRepresentable {
    @Binding var selectedMembers: Set<Member>
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0")
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let newMembers = contacts.compactMap { Member.fromContact($0) }
            parent.selectedMembers.formUnion(newMembers)
        }
    }
}

extension String {
    func isValidEmail() -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
} 