import Foundation
import Contacts

struct Member: Identifiable, Hashable {
    let id: String
    let email: String
    let name: String
    let source: MemberSource
    var isSelected: Bool
    
    enum MemberSource {
        case existingGroup
        case contacts
        case manual
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Member, rhs: Member) -> Bool {
        lhs.id == rhs.id
    }
    
    static func fromContact(_ contact: CNContact) -> Member? {
        guard let email = contact.emailAddresses.first?.value as String? else { return nil }
        return Member(
            id: contact.identifier,
            email: email,
            name: "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces),
            source: .contacts,
            isSelected: false
        )
    }
} 