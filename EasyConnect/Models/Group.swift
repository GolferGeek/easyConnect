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
    let groupTypeId: Int
    
    var isOwner: Bool {
        role == "admin"
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
        case declined = "declined"
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
        case groupTypeId = "group_type_id"
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
         memberCount: Int,
         groupTypeId: Int) {
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
        self.groupTypeId = groupTypeId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        groupId = try container.decode(String.self, forKey: .groupId)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        visibility = try container.decode(GroupVisibility.self, forKey: .visibility)
        joinMethod = try container.decode(JoinMethod.self, forKey: .joinMethod)
        role = try container.decode(String.self, forKey: .role)
        status = try container.decode(MemberStatus.self, forKey: .status)
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        groupTypeId = try container.decode(Int.self, forKey: .groupTypeId)
        
        if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: dateString)
        } else {
            createdAt = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(groupId, forKey: .groupId)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(joinMethod, forKey: .joinMethod)
        try container.encode(role, forKey: .role)
        try container.encode(status, forKey: .status)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encode(createdBy, forKey: .createdBy)
        
        if let createdAt = createdAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: createdAt), forKey: .createdAt)
        }
    }
} 