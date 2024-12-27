import SwiftUI

struct GroupMemberRow: View {
    let member: GroupMember
    var onResend: (() -> Void)?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(member.name)
                    .font(.headline)
                Text(member.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if member.status == .invited {
                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.orange)
                if let onResend = onResend {
                    Button("Resend", action: onResend)
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            } else if member.status == .declined {
                Text("Declined")
                    .font(.caption)
                    .foregroundColor(.red)
                if let onResend = onResend {
                    Button("Resend", action: onResend)
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            }
            
            if member.role == "admin" {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
    }
} 