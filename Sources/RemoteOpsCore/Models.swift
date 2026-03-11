import Foundation

public enum SessionType: String, Codable, Sendable {
    case ssh
    case awsEC2
    case awsECSExec
}

public struct Session: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: SessionType
    public var host: String
    public var port: Int
    public var username: String

    public init(
        id: UUID = UUID(),
        name: String,
        type: SessionType,
        host: String,
        port: Int = 22,
        username: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.port = port
        self.username = username
    }
}

public struct EnvironmentProfile: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var sessionID: Session.ID
    public var workingDirectory: String?
    public var shell: String
    public var preferredModel: String
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        sessionID: Session.ID,
        workingDirectory: String? = nil,
        shell: String = "/bin/bash",
        preferredModel: String = "openrouter/gpt-4o-mini",
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.sessionID = sessionID
        self.workingDirectory = workingDirectory
        self.shell = shell
        self.preferredModel = preferredModel
        self.tags = tags
    }
}

public enum CommandSource: String, Codable, Sendable {
    case askAI
    case history
    case paste
    case typed
}

public enum RiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
}

public struct AIProposal: Equatable, Codable, Sendable {
    public var command: String
    public var explanation: String
    public var risk: RiskLevel
    public var alternatives: [String]

    public init(command: String, explanation: String, risk: RiskLevel, alternatives: [String] = []) {
        self.command = command
        self.explanation = explanation
        self.risk = risk
        self.alternatives = alternatives
    }
}

public struct ClipboardReview: Equatable, Sendable {
    public var originalText: String
    public var command: String
    public var risk: RiskLevel
    public var warnings: [String]

    public init(originalText: String, command: String, risk: RiskLevel, warnings: [String] = []) {
        self.originalText = originalText
        self.command = command
        self.risk = risk
        self.warnings = warnings
    }
}

public struct CommandRecord: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public var sessionID: Session.ID
    public var environmentID: EnvironmentProfile.ID?
    public var command: String
    public var source: CommandSource
    public var risk: RiskLevel
    public var pinned: Bool
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionID: Session.ID,
        environmentID: EnvironmentProfile.ID? = nil,
        command: String,
        source: CommandSource,
        risk: RiskLevel,
        pinned: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.environmentID = environmentID
        self.command = command
        self.source = source
        self.risk = risk
        self.pinned = pinned
        self.deletedAt = deletedAt
    }
}
