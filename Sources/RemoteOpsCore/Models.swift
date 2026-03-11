import Foundation

public enum SessionType: String, Codable, Sendable {
    case ssh
    case awsEC2
    case awsECSExec
    case openCodePlaceholder
}

public enum EnvironmentLabel: String, Codable, Sendable {
    case production
    case staging
    case development
    case personal
    case custom
}

public enum RiskMode: String, Codable, Sendable {
    case standard
    case cautious
    case strict
}

public struct Session: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: SessionType
    public var host: String
    public var port: Int
    public var username: String
    public var tags: [String]
    public var environmentIDs: [EnvironmentProfile.ID]
    public var isFavorite: Bool
    public var isArchived: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        type: SessionType,
        host: String,
        port: Int = 22,
        username: String,
        tags: [String] = [],
        environmentIDs: [EnvironmentProfile.ID] = [],
        isFavorite: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.port = port
        self.username = username
        self.tags = tags
        self.environmentIDs = environmentIDs
        self.isFavorite = isFavorite
        self.isArchived = isArchived
    }
}

public struct EnvironmentProfile: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var sessionID: Session.ID
    public var workingDirectory: String?
    public var shell: String
    public var variables: [String: String]
    public var label: EnvironmentLabel
    public var preferredAIProvider: String
    public var preferredModel: String
    public var riskMode: RiskMode
    public var notes: String?
    public var isFavorite: Bool
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        sessionID: Session.ID,
        workingDirectory: String? = nil,
        shell: String = "/bin/bash",
        variables: [String: String] = [:],
        label: EnvironmentLabel = .development,
        preferredAIProvider: String = "openrouter",
        preferredModel: String = "openrouter/gpt-4o-mini",
        riskMode: RiskMode = .standard,
        notes: String? = nil,
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.sessionID = sessionID
        self.workingDirectory = workingDirectory
        self.shell = shell
        self.variables = variables
        self.label = label
        self.preferredAIProvider = preferredAIProvider
        self.preferredModel = preferredModel
        self.riskMode = riskMode
        self.notes = notes
        self.isFavorite = isFavorite
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
    public var nlPrompt: String?
    public var wasEdited: Bool
    public var exitCode: Int?
    public var outputPreview: String?
    public var pinned: Bool
    public var deletedAt: Date?
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionID: Session.ID,
        environmentID: EnvironmentProfile.ID? = nil,
        command: String,
        source: CommandSource,
        risk: RiskLevel,
        nlPrompt: String? = nil,
        wasEdited: Bool = false,
        exitCode: Int? = nil,
        outputPreview: String? = nil,
        pinned: Bool = false,
        deletedAt: Date? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.environmentID = environmentID
        self.command = command
        self.source = source
        self.risk = risk
        self.nlPrompt = nlPrompt
        self.wasEdited = wasEdited
        self.exitCode = exitCode
        self.outputPreview = outputPreview
        self.pinned = pinned
        self.deletedAt = deletedAt
        self.tags = tags
    }
}
