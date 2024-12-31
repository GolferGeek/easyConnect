import SwiftUI

struct MemberButton: View {
    let member: GroupMember
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {}) {
            Text(member.name.components(separatedBy: "@").first ?? member.name)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isHovering ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $isHovering) {
            VStack(alignment: .leading, spacing: 8) {
                Text(member.name)
                    .font(.headline)
                Text(member.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                if member.role == "admin" {
                    Label("Admin", systemImage: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            .padding()
            .frame(minWidth: 200)
        }
    }
} 