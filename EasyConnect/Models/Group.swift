import Foundation

struct Group: Identifiable, Codable {
    var id: String { groupId }  // Computed property for Identifiable conformance
    let groupId: String
    let userId: String
    let name: String
    let description: String?
    let visibility: GroupVisibility
    let joinMethod: JoinMethod
    let createdAt: Date?
    let createdBy: String?
    let role: String
    let status: MemberStatus
    let memberCount: Int
    
    var isOwner: Bool {
        role == "admin"
    }
    
    init(groupId: String,
         userId: String,
         name: String,
         description: String?,
         visibility: GroupVisibility,
         joinMethod: JoinMethod,
         createdAt: Date?,
         createdBy: String?,
         role: String,
         status: MemberStatus,
         memberCount: Int) {
        self.groupId = groupId
        self.userId = userId
        self.name = name
        self.description = description
        self.visibility = visibility
        self.joinMethod = joinMethod
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.role = role
        self.status = status
        self.memberCount = memberCount
    }
    
    enum GroupVisibility: String, Codable {
        case `public` = "public"
        case `private` = "private"
    }
    
    enum JoinMethod: String, Codable {
        case direct = "direct"
        case invitation = "invitation"
    }
    
    enum MemberStatus: String, Codable {
        case invited = "invited"
        case joined = "joined"
    }
    
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case name
        case description
        case visibility
        case joinMethod = "join_method"
        case createdAt = "created_at"
        case createdBy = "created_by"
        case role
        case status
        case memberCount = "member_count"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        groupId = try container.decode(String.self, forKey: .groupId)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        visibility = try container.decodeIfPresent(GroupVisibility.self, forKey: .visibility) ?? .private
        joinMethod = try container.decodeIfPresent(JoinMethod.self, forKey: .joinMethod) ?? .invitation
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        role = try container.decode(String.self, forKey: .role)
        status = try container.decodeIfPresent(MemberStatus.self, forKey: .status) ?? .invited
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
    }
} 