import Foundation
import Supabase

class GroupManager: ObservableObject {
    @Published var groups: [Group] = []
    @Published var existingMembers: [Member] = []
    @Published var allUsers: [Member] = []
    @Published var isLoading = true
    @Published var groupTypes: [GroupType] = []
    @Published var pendingInvites: [GroupInvite] = []
    
    private let supabase = SupabaseManager.shared
    private let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
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
        print("Starting fetchExistingMembers")
        guard let userId = authManager.currentUser?.id else {
            print("No current user ID found")
            return
        }
        print("Fetching for user ID: \(userId)")
        
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
        print("Groups response data: \(String(data: groupsResponse.data, encoding: .utf8) ?? "unable to decode")")
        
        let decoder = JSONDecoder()
        let groupsResult = try decoder.decode([GroupMemberBasic].self, from: groupsResponse.data)
        print("Decoded \(groupsResult.count) groups")
        
        // Then, for each group, get its members
        var uniqueMembers: Set<Member> = []
        
        for groupMember in groupsResult {
            print("Fetching members for group: \(groupMember.groups.id)")
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
            print("Members response data: \(String(data: membersResponse.data, encoding: .utf8) ?? "unable to decode")")
            
            let membersResult = try decoder.decode([MemberResponse].self, from: membersResponse.data)
            print("Decoded \(membersResult.count) members for group \(groupMember.groups.id)")
            
            for memberResponse in membersResult {
                let member = Member(
                    id: memberResponse.userId,
                    email: memberResponse.profiles.email,
                    name: memberResponse.profiles.username ?? memberResponse.profiles.email,
                    source: .existingGroup,
                    isSelected: false
                )
                uniqueMembers.insert(member)
            }
        }
        
        print("Total unique members found: \(uniqueMembers.count)")
        DispatchQueue.main.async {
            self.existingMembers = Array(uniqueMembers)
            print("Updated existingMembers with \(self.existingMembers.count) members")
        }
    }
    
    func fetchAllUsers() async throws {
        print("Starting fetchAllUsers")
        guard let userId = authManager.currentUser?.id else {
            print("No current user ID found")
            return
        }
        print("Fetching all users except: \(userId)")
        
        let query = supabase.client.database
            .from("profiles")
            .select("id, email, username")
            .neq("id", value: userId)
        
        let response = try await query.execute()
        print("All users response data: \(String(data: response.data, encoding: .utf8) ?? "unable to decode")")
        
        let decoder = JSONDecoder()
        let profiles = try decoder.decode([ProfileResponse].self, from: response.data)
        print("Decoded \(profiles.count) users")
        
        let users = profiles.map { profile in
            Member(
                id: profile.id,
                email: profile.email,
                name: profile.username ?? profile.email,
                source: .existingGroup,
                isSelected: false
            )
        }
        
        DispatchQueue.main.async {
            self.allUsers = users
            print("Updated allUsers with \(self.allUsers.count) users")
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
        let profiles: ProfileData
        
        struct ProfileData: Codable {
            let email: String
            let username: String?
        }
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case profiles
        }
    }
    
    private struct ProfileResponse: Codable {
        let id: String
        let email: String
        let username: String?
    }
    
    func addMembers(groupId: String, members: [Member]) async throws {
        print("Adding members to group \(groupId): \(members)")
        
        // First, get valid user IDs for all members
        let emails = members.map { $0.email }
        print("Looking up emails: \(emails)")
        
        let emailList = emails.map { "'\($0)'" }.joined(separator: ",")
        let profilesQuery = supabase.client.database
            .from("profiles")
            .select("id, email")
            .filter("email", operator: "in", value: "(\(emailList))")
        
        print("Query filter value: (\(emailList))")
        
        let profilesResponse = try await profilesQuery.execute()
        print("Raw response data: \(String(data: profilesResponse.data, encoding: .utf8) ?? "unable to decode")")
        
        // Try to decode as a generic JSON first to see the structure
        if let json = try? JSONSerialization.jsonObject(with: profilesResponse.data) {
            print("JSON structure: \(json)")
        }
        
        struct SimpleProfileResponse: Codable {
            let id: String
            let email: String
        }
        
        let decoder = JSONDecoder()
        do {
            let profiles = try decoder.decode([SimpleProfileResponse].self, from: profilesResponse.data)
            print("Successfully decoded \(profiles.count) profiles")
            
            // Create a mapping of email to user ID
            let emailToUserId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.email.lowercased(), $0.id) })
            print("Email to user ID mapping: \(emailToUserId)")
            
            // Filter out members that don't have a valid user ID
            let validMembers = members.compactMap { member -> [String: String]? in
                guard let userId = emailToUserId[member.email.lowercased()] else { 
                    print("No user ID found for email: \(member.email)")
                    return nil 
                }
                return [
                    "group_id": groupId,
                    "user_id": userId,
                    "role": "member",
                    "status": "joined"
                ]
            }
            
            guard !validMembers.isEmpty else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid users found. Make sure the selected users have accounts in the system."])
            }
            
            print("Valid member inserts: \(validMembers)")
            
            let query = try supabase.client.database
                .from("group_members")
                .insert(validMembers)
            
            let response = try await query.execute()
            print("Add members response: \(String(data: response.data, encoding: .utf8) ?? "unable to decode")")
        } catch {
            print("Decoding error: \(error)")
            throw error
        }
    }
    
    func createGroup(name: String, description: String?, visibility: Group.GroupVisibility, joinMethod: Group.JoinMethod, userId: String, groupTypeId: Int) async throws -> String {
        let payload = CreateGroupPayload(
            name: name,
            description: description,
            visibility: visibility,
            joinMethod: joinMethod,
            userId: userId,
            groupTypeId: groupTypeId
        )
        
        // First, create the group
        let createQuery = try supabase.client.database
            .from("groups")
            .insert(payload)
            .select()
            .single()
        
        let response = try await createQuery.execute()
        let jsonData = response.data
        
        struct GroupResponse: Codable {
            let id: String
        }
        
        let decoder = JSONDecoder()
        let group = try decoder.decode(GroupResponse.self, from: jsonData)
        
        // Then, add the creator as an admin member
        let memberPayload = [
            "group_id": group.id,
            "user_id": userId,
            "role": "admin",
            "status": "joined"
        ]
        
        let memberQuery = try supabase.client.database
            .from("group_members")
            .insert(memberPayload)
        
        try await memberQuery.execute()
        
        return group.id
    }
    
    func fetchGroups() async {
        guard let userId = authManager.currentUser?.id else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            async let groupsTask = fetchUserGroups(userId: userId)
            async let invitesTask = fetchPendingInvites()
            
            let (groups, invites) = try await (groupsTask, invitesTask)
            print("Fetched \(groups.count) groups")
            
            DispatchQueue.main.async {
                self.groups = groups
                self.pendingInvites = invites
                self.isLoading = false
            }
        } catch {
            print("Error fetching groups: \(error)")
            if let supabaseError = error as? PostgrestError {
                print("Supabase error details: \(supabaseError)")
            }
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func fetchUserGroups(userId: String) async throws -> [Group] {
        print("Fetching groups for user: \(userId)")
        let query = supabase.client.database
            .from("group_members")
            .select("""
                groups!inner (
                    id,
                    name,
                    description,
                    visibility,
                    join_method,
                    created_at,
                    created_by,
                    group_type_id
                ),
                role,
                status,
                profiles!inner (
                    id,
                    email
                )
            """)
            .eq("user_id", value: userId)
            .eq("status", value: "joined")
        
        let response = try await query.execute()
        let jsonData = response.data
        print("Raw response data: \(String(data: jsonData, encoding: .utf8) ?? "unable to decode")")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let groupResponses = try decoder.decode([GroupResponse].self, from: jsonData)
        print("Decoded \(groupResponses.count) group responses")
        
        struct GroupResponse: Codable {
            let groups: GroupData
            let role: String
            let status: Group.MemberStatus
            let profiles: ProfileData
            
            struct GroupData: Codable {
                let id: String
                let name: String
                let description: String?
                let visibility: Group.GroupVisibility
                let joinMethod: Group.JoinMethod
                let createdAt: Date?
                let createdBy: String?
                let groupTypeId: Int
                
                enum CodingKeys: String, CodingKey {
                    case id, name, description, visibility
                    case joinMethod = "join_method"
                    case createdAt = "created_at"
                    case createdBy = "created_by"
                    case groupTypeId = "group_type_id"
                }
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    id = try container.decode(String.self, forKey: .id)
                    name = try container.decode(String.self, forKey: .name)
                    description = try container.decodeIfPresent(String.self, forKey: .description)
                    visibility = try container.decode(Group.GroupVisibility.self, forKey: .visibility)
                    joinMethod = try container.decode(Group.JoinMethod.self, forKey: .joinMethod)
                    createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
                    groupTypeId = try container.decode(Int.self, forKey: .groupTypeId)
                    
                    if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let date = formatter.date(from: dateString) {
                            createdAt = date
                        } else {
                            createdAt = nil
                        }
                    } else {
                        createdAt = nil
                    }
                }
            }
            
            struct ProfileData: Codable {
                let id: String
                let email: String
            }
            
            enum CodingKeys: String, CodingKey {
                case groups, role, status, profiles
            }
        }
        
        // Create groups with a default member count of 1 (the current user)
        var groups = groupResponses.map { response in
            Group(
                groupId: response.groups.id,
                userId: response.profiles.id,
                name: response.groups.name,
                description: response.groups.description,
                visibility: response.groups.visibility,
                joinMethod: response.groups.joinMethod,
                createdAt: response.groups.createdAt,
                createdBy: response.groups.createdBy,
                role: response.role,
                status: response.status,
                memberCount: 1,  // Start with 1 for the current user
                groupTypeId: response.groups.groupTypeId
            )
        }
        
        // Then update member counts for each group
        for i in 0..<groups.count {
            let countQuery = supabase.client.database
                .from("group_members")
                .select("*", head: false, count: .exact)
                .eq("group_id", value: groups[i].groupId)
                .eq("status", value: "joined")
            
            let countResponse = try await countQuery.execute()
            if let count = countResponse.count {
                groups[i] = Group(
                    groupId: groups[i].groupId,
                    userId: groups[i].userId,
                    name: groups[i].name,
                    description: groups[i].description,
                    visibility: groups[i].visibility,
                    joinMethod: groups[i].joinMethod,
                    createdAt: groups[i].createdAt,
                    createdBy: groups[i].createdBy,
                    role: groups[i].role,
                    status: groups[i].status,
                    memberCount: count,
                    groupTypeId: groups[i].groupTypeId
                )
            }
        }
        
        return groups
    }
    
    func deleteGroup(id: String) async throws {
        // First delete all group members
        let membersQuery = supabase.client.database
            .from("group_members")
            .delete()
            .eq("group_id", value: id)
        
        try await membersQuery.execute()
        
        // Then delete all activities
        let activitiesQuery = supabase.client.database
            .from("activities")
            .delete()
            .eq("group_id", value: id)
        
        try await activitiesQuery.execute()
        
        // Finally delete the group
        let groupQuery = supabase.client.database
            .from("groups")
            .delete()
            .eq("id", value: id)
        
        try await groupQuery.execute()
        
        // Update local state
        await fetchGroups()
    }
    
    func fetchGroup(id: String) async throws -> Group {
        guard let userId = authManager.currentUser?.id else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let query = supabase.client.database
            .from("group_members")
            .select("""
                groups!inner (
                    id,
                    name,
                    description,
                    visibility,
                    join_method,
                    created_at,
                    created_by,
                    group_type_id
                ),
                role,
                status,
                profiles!inner (
                    id,
                    email
                )
            """)
            .eq("group_id", value: id)
            .eq("user_id", value: userId)
            .eq("status", value: "joined")
            .single()
        
        do {
            let response = try await query.execute()
            let jsonData = response.data
            
            struct GroupResponse: Codable {
                let groups: GroupData
                let role: String
                let status: Group.MemberStatus
                let profiles: ProfileData
                
                struct GroupData: Codable {
                    let id: String
                    let name: String
                    let description: String?
                    let visibility: Group.GroupVisibility
                    let joinMethod: Group.JoinMethod
                    let createdAt: Date?
                    let createdBy: String?
                    let groupTypeId: Int
                    
                    enum CodingKeys: String, CodingKey {
                        case id, name, description, visibility
                        case joinMethod = "join_method"
                        case createdAt = "created_at"
                        case createdBy = "created_by"
                        case groupTypeId = "group_type_id"
                    }
                    
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        id = try container.decode(String.self, forKey: .id)
                        name = try container.decode(String.self, forKey: .name)
                        description = try container.decodeIfPresent(String.self, forKey: .description)
                        visibility = try container.decode(Group.GroupVisibility.self, forKey: .visibility)
                        joinMethod = try container.decode(Group.JoinMethod.self, forKey: .joinMethod)
                        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
                        groupTypeId = try container.decode(Int.self, forKey: .groupTypeId)
                        
                        if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            if let date = formatter.date(from: dateString) {
                                createdAt = date
                            } else {
                                createdAt = nil
                            }
                        } else {
                            createdAt = nil
                        }
                    }
                }
                
                struct ProfileData: Codable {
                    let id: String
                    let email: String
                }
            }
            
            let decoder = JSONDecoder()
            let groupResponse = try decoder.decode(GroupResponse.self, from: jsonData)
            
            // Get member count
            let countQuery = supabase.client.database
                .from("group_members")
                .select("*", head: false, count: .exact)
                .eq("group_id", value: id)
                .eq("status", value: "joined")
            
            let countResponse = try await countQuery.execute()
            let memberCount = countResponse.count ?? 0
            
            return Group(
                groupId: groupResponse.groups.id,
                userId: groupResponse.profiles.id,
                name: groupResponse.groups.name,
                description: groupResponse.groups.description,
                visibility: groupResponse.groups.visibility,
                joinMethod: groupResponse.groups.joinMethod,
                createdAt: groupResponse.groups.createdAt,
                createdBy: groupResponse.groups.createdBy,
                role: groupResponse.role,
                status: groupResponse.status,
                memberCount: memberCount,
                groupTypeId: groupResponse.groups.groupTypeId
            )
        } catch {
            print("Error fetching group: \(error)")
            if let supabaseError = error as? PostgrestError {
                print("Supabase error: \(supabaseError)")
            }
            throw error
        }
    }
    
    func updateGroup(id: String, name: String, description: String?, visibility: Group.GroupVisibility, joinMethod: Group.JoinMethod, groupTypeId: Int) async throws {
        struct UpdateGroupPayload: Encodable {
            let name: String
            let description: String?
            let visibility: Group.GroupVisibility
            let joinMethod: Group.JoinMethod
            let groupTypeId: Int
            
            enum CodingKeys: String, CodingKey {
                case name, description, visibility
                case joinMethod = "join_method"
                case groupTypeId = "group_type_id"
            }
        }
        
        let payload = UpdateGroupPayload(
            name: name,
            description: description,
            visibility: visibility,
            joinMethod: joinMethod,
            groupTypeId: groupTypeId
        )
        
        let query = try supabase.client.database
            .from("groups")
            .update(payload)
            .eq("id", value: id)
        
        try await query.execute()
        
        // Update local state
        await fetchGroups()
    }
    
    func inviteMembers(groupId: String, emails: [String]) async throws -> [InviteResult] {
        var results: [InviteResult] = []
        
        // First, check which emails exist in profiles
        let query = supabase.client.database
            .from("profiles")
            .select("id, email")
            .filter("email", operator: "in", value: "(\(emails.map { "'\($0)'" }.joined(separator: ",")))")
        
        let response = try await query.execute()
        let decoder = JSONDecoder()
        let existingProfiles = try decoder.decode([ProfileResponse].self, from: response.data)
        let existingEmails = Set(existingProfiles.map { $0.email.lowercased() })
        
        // Create invites for existing users
        let invites = existingProfiles.map { profile in
            [
                "group_id": groupId,
                "user_id": profile.id,
                "role": "member",
                "status": "invited"
            ]
        }
        
        if !invites.isEmpty {
            let inviteQuery = try supabase.client.database
                .from("group_members")
                .insert(invites)
            
            try await inviteQuery.execute()
            
            // Add results for existing users
            results.append(contentsOf: existingProfiles.map { profile in
                InviteResult(email: profile.email, status: .invited)
            })
        }
        
        // Collect emails that need system invites
        let newUserEmails = emails.filter { !existingEmails.contains($0.lowercased()) }
        results.append(contentsOf: newUserEmails.map { email in
            InviteResult(email: email, status: .needsSystemInvite)
        })
        
        return results
    }
    
    func fetchPendingInvites() async throws -> [GroupInvite] {
        guard let userId = authManager.currentUser?.id else { return [] }
        
        let query = supabase.client.database
            .from("group_members")
            .select("""
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
            .eq("user_id", value: userId)
            .eq("status", value: "invited")
        
        let response = try await query.execute()
        let decoder = JSONDecoder()
        let invites = try decoder.decode([GroupInvite].self, from: response.data)
        return invites
    }
    
    func respondToInvite(groupId: String, accept: Bool) async throws {
        guard let userId = authManager.currentUser?.id else { return }
        
        let status = accept ? "joined" : "declined"
        let query = try supabase.client.database
            .from("group_members")
            .update(["status": status])
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
        
        try await query.execute()
        
        // Refresh groups list if accepted
        if accept {
            await fetchGroups()
        }
    }
    
    func fetchGroupMembers(groupId: String) async throws -> [GroupMember] {
        let query = supabase.client.database
            .from("group_members")
            .select("""
                user_id,
                role,
                status,
                profiles!inner(
                    email,
                    username
                )
            """)
            .eq("group_id", value: groupId)
        
        let response = try await query.execute()
        let jsonData = response.data
        
        struct MemberResponse: Codable {
            let userId: String
            let role: String
            let status: Group.MemberStatus
            let profiles: ProfileData
            
            struct ProfileData: Codable {
                let email: String
                let username: String?
            }
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case role, status, profiles
            }
        }
        
        let decoder = JSONDecoder()
        let members = try decoder.decode([MemberResponse].self, from: jsonData)
        
        return members.map { member in
            GroupMember(
                userId: member.userId,
                name: member.profiles.username ?? member.profiles.email,
                email: member.profiles.email,
                role: member.role,
                status: member.status
            )
        }
    }
    
    func resendInvite(groupId: String, userId: String) async throws {
        // First, update the status back to "invited"
        let query = try supabase.client.database
            .from("group_members")
            .update(["status": "invited"])
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
        
        try await query.execute()
        
        // TODO: Send notification or email to user about the re-invitation
    }
    
    struct InviteResult {
        let email: String
        let status: InviteStatus
        
        enum InviteStatus {
            case invited           // User exists and was invited
            case needsSystemInvite // User needs to be invited to the system
        }
    }
    
    struct GroupInvite: Codable {
        let groups: GroupData
        
        struct GroupData: Codable {
            let id: String
            let name: String
            let description: String?
            let visibility: Group.GroupVisibility
            let joinMethod: Group.JoinMethod
            let createdAt: Date?
            let createdBy: String?
            
            enum CodingKeys: String, CodingKey {
                case id, name, description, visibility
                case joinMethod = "join_method"
                case createdAt = "created_at"
                case createdBy = "created_by"
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                name = try container.decode(String.self, forKey: .name)
                description = try container.decodeIfPresent(String.self, forKey: .description)
                visibility = try container.decode(Group.GroupVisibility.self, forKey: .visibility)
                joinMethod = try container.decode(Group.JoinMethod.self, forKey: .joinMethod)
                createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
                
                if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: dateString) {
                        createdAt = date
                    } else {
                        createdAt = nil
                    }
                } else {
                    createdAt = nil
                }
            }
        }
    }
} 
