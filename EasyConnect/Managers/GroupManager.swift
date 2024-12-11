import Foundation
import Supabase

class GroupManager: ObservableObject {
    @Published var groups: [Group] = []
    @Published var existingMembers: [Member] = []
    @Published var isLoading = true
    
    private let supabase = SupabaseManager.shared
    private let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    struct CreateGroupPayload: Encodable {
        let name: String
        let description: String?
        let visibility: Group.GroupVisibility
        let join_method: Group.JoinMethod
        let created_by: String
        let created_at: Date
        let group_type_id: Int
        
        init(name: String, description: String?, visibility: Group.GroupVisibility, joinMethod: Group.JoinMethod, userId: String, groupTypeId: Int) {
            self.name = name
            self.description = description
            self.visibility = visibility
            self.join_method = joinMethod
            self.created_by = userId
            self.created_at = Date()
            self.group_type_id = groupTypeId
        }
    }
    
    func fetchExistingMembers() async throws {
        guard let userId = authManager.currentUser?.id else { return }
        
        // First, get all groups where the user is a member
        let groupsQuery = supabase.client.database
            .from("group_members")
            .select("""
                groups!inner(
                    id,
                    name
                )
            """)
            .eq("user_id", value: userId)
            .eq("status", value: "joined")
        
        let groupsResponse = try await groupsQuery.execute()
        let groupsData = groupsResponse.data
        
        let decoder = JSONDecoder()
        let groupsResult = try decoder.decode([GroupMemberBasic].self, from: groupsData)
        
        // Then, for each group, get its members
        var uniqueMembers: Set<Member> = []
        
        for groupMember in groupsResult {
            let membersQuery = supabase.client.database
                .from("group_members")
                .select("""
                    user_id,
                    profiles!inner(
                        email,
                        username
                    )
                """)
                .eq("group_id", value: groupMember.groups.id)
                .eq("status", value: "joined")
                .neq("user_id", value: userId) // Exclude current user
            
            let membersResponse = try await membersQuery.execute()
            let membersData = membersResponse.data
            let membersResult = try decoder.decode([MemberResponse].self, from: membersData)
            
            for memberResponse in membersResult {
                let member = Member(
                    id: memberResponse.userId,
                    email: memberResponse.profile.email,
                    name: memberResponse.profile.username ?? memberResponse.profile.email,
                    source: .existingGroup,
                    isSelected: false
                )
                uniqueMembers.insert(member)
            }
        }
        
        DispatchQueue.main.async {
            self.existingMembers = Array(uniqueMembers)
        }
    }
    
    private struct GroupMemberBasic: Codable {
        let groups: GroupBasic
        
        struct GroupBasic: Codable {
            let id: String
            let name: String
        }
    }
    
    private struct MemberResponse: Codable {
        let userId: String
        let profile: UserProfile
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case profile = "profiles"
        }
        
        struct UserProfile: Codable {
            let email: String
            let username: String?
            
            enum CodingKeys: String, CodingKey {
                case email
                case username
            }
        }
    }
    
    func sendInvitation(email: String, groupId: String) async throws {
        // First, get the user ID from the profiles table
        let userQuery = supabase.client.database
            .from("profiles")
            .select("id")
            .eq("email", value: email)
            .single()
        
        let userData = try await userQuery.execute()
        let jsonData = userData.data
        let decoder = JSONDecoder()
        
        struct UserProfile: Codable {
            let id: String
        }
        
        guard let profile = try? decoder.decode(UserProfile.self, from: jsonData) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found for email: \(email)"])
        }
        
        // Create group member with invited status using the user's ID
        try await supabase.client.database
            .from("group_members")
            .insert([
                "group_id": groupId,
                "user_id": profile.id,
                "role": "member",
                "status": "invited"
            ])
            .execute()
        
        // Note: Email notifications can be implemented later using a different mechanism
        // For now, users will see their invitations when they log in
    }
    
    func fetchGroups() async {
        isLoading = true
        do {
            let query = supabase.client.database
                .from("group_members")
                .select("""
                    group_id,
                    user_id,
                    role,
                    status,
                    groups!inner(
                        id,
                        name,
                        description,
                        visibility,
                        join_method,
                        created_at,
                        created_by
                    )
                """)
                .eq("user_id", value: authManager.currentUser?.id ?? "")
            
            let response = try await query.execute()
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let rows = try decoder.decode([GroupMemberResponse].self, from: jsonData)
            let groupIds = Set(rows.map { $0.groups.id })
            
            // Fetch member counts for each group
            var memberCounts: [String: Int] = [:]
            for groupId in groupIds {
                let countQuery = supabase.client.database
                    .from("group_members")
                    .select("*", head: true, count: .exact)
                    .eq("group_id", value: groupId)
                
                let countResponse = try await countQuery.execute()
                if let count = countResponse.count {
                    memberCounts[groupId] = count
                }
            }
            
            let groups = rows.map { row -> Group in
                Group(
                    groupId: row.groups.id,
                    userId: row.userId,
                    name: row.groups.name,
                    description: row.groups.description,
                    visibility: Group.GroupVisibility(rawValue: row.groups.visibility) ?? .private,
                    joinMethod: Group.JoinMethod(rawValue: row.groups.joinMethod) ?? .invitation,
                    createdAt: ISO8601DateFormatter().date(from: row.groups.createdAt ?? ""),
                    createdBy: row.groups.createdBy,
                    role: row.role,
                    status: Group.MemberStatus(rawValue: row.status) ?? .invited,
                    memberCount: memberCounts[row.groups.id] ?? 0
                )
            }
            
            DispatchQueue.main.async {
                self.groups = groups
                self.isLoading = false
            }
        } catch {
            print("Error fetching groups: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.groups = []
            }
        }
    }
    
    private struct GroupMemberResponse: Codable {
        let groupId: String
        let userId: String
        let role: String
        let status: String
        let groups: GroupResponse
        
        enum CodingKeys: String, CodingKey {
            case groupId = "group_id"
            case userId = "user_id"
            case role
            case status
            case groups
        }
    }
    
    private struct GroupResponse: Codable {
        let id: String
        let name: String
        let description: String?
        let visibility: String
        let joinMethod: String
        let createdAt: String?
        let createdBy: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case description
            case visibility
            case joinMethod = "join_method"
            case createdAt = "created_at"
            case createdBy = "created_by"
        }
    }
    
    func deleteGroup(id: String) async throws {
        try await supabase.client.database
            .from("group_members")
            .delete()
            .eq("group_id", value: id)
            .execute()
        
        try await supabase.client.database
            .from("groups")
            .delete()
            .eq("id", value: id)
            .execute()
        
        await fetchGroups()
    }
    
    func createGroup(
        name: String,
        description: String?,
        visibility: Group.GroupVisibility,
        joinMethod: Group.JoinMethod,
        userId: String,
        groupTypeId: Int
    ) async throws -> String {
        let payload = CreateGroupPayload(
            name: name,
            description: description,
            visibility: visibility,
            joinMethod: joinMethod,
            userId: userId,
            groupTypeId: groupTypeId
        )
        
        let groupResponse = try await supabase.client.database
            .from("groups")
            .insert(payload)
            .select()
            .execute()
            
        let jsonData = groupResponse.data
        let decoder = JSONDecoder()
        
        struct GroupCreateResponse: Codable {
            let id: String
        }
        
        let groups = try decoder.decode([GroupCreateResponse].self, from: jsonData)
        guard let groupId = groups.first?.id else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get group ID"])
        }
        
        // Add creator as admin
        try await supabase.client.database
            .from("group_members")
            .insert([
                "group_id": groupId,
                "user_id": userId,
                "role": "admin",
                "status": "joined"
            ])
            .execute()
        
        await fetchGroups()
        return groupId
    }
    
    func addMembers(groupId: String, members: [Member]) async throws {
        for member in members {
            if member.source == .existingGroup {
                // For existing users, directly create the group membership
                try await supabase.client.database
                    .from("group_members")
                    .insert([
                        "group_id": groupId,
                        "user_id": member.id,
                        "role": "member",
                        "status": "invited"
                    ])
                    .execute()
            } else {
                // For new invites (contacts or manual email), use the invitation process
                try await sendInvitation(email: member.email, groupId: groupId)
            }
        }
    }
    
    func acceptInvitation(groupId: String) async throws {
        guard let userId = authManager.currentUser?.id else { return }
        
        try await supabase.client.database
            .from("group_members")
            .update(["status": "joined"])
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
        
        await fetchGroups()
    }
    
    func declineInvitation(groupId: String) async throws {
        guard let userId = authManager.currentUser?.id else { return }
        
        try await supabase.client.database
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
        
        await fetchGroups()
    }
    
    struct GroupType: Codable {
        let id: Int
        let groupType: String
        let subTypes: [SubType]
        
        struct SubType: Codable, Identifiable, Hashable {
            let id: Int?
            let name: String
            let description: String
            
            // Implement Hashable since id is optional
            func hash(into hasher: inout Hasher) {
                hasher.combine(name)
                hasher.combine(description)
            }
            
            static func == (lhs: SubType, rhs: SubType) -> Bool {
                lhs.name == rhs.name && lhs.description == rhs.description
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case groupType = "group_type"
            case subTypes = "sub_types"
        }
    }
    
    @Published var groupTypes: [GroupType] = []
    
    func fetchGroupTypes() async throws {
        let response = try await supabase.client.database
            .from("group_types")
            .select("id, group_type, sub_types")
            .execute()
            
        let jsonData = response.data
        let decoder = JSONDecoder()
        let types = try decoder.decode([GroupType].self, from: jsonData)
        
        DispatchQueue.main.async {
            self.groupTypes = types
        }
    }
} 
