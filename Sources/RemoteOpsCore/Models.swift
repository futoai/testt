import Foundation

public enum SessionType: String, Codable, Sendable {
    case ssh
    case awsEC2
    case awsECSExec
    case savedEnvironment
    case openCodePlaceholder
}

public struct SecretRef: Equatable, Codable, Sendable {
    public var key: String
    public var kind: String

    public init(key: String, kind: String) {
        self.key = key
        self.kind = kind
    }
}

public struct AuthProfile: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var provider: String
    public var accountHint: String?
    public var secretRef: SecretRef?

    public init(
        id: UUID = UUID(),
        name: String,
        provider: String,
        accountHint: String? = nil,
        secretRef: SecretRef? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.accountHint = accountHint
        self.secretRef = secretRef
    }
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
    public var lastConnectedAt: Date?

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
        isArchived: Bool = false,
        lastConnectedAt: Date? = nil
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
        self.lastConnectedAt = lastConnectedAt
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
    public var assumptions: [String]

    public init(
        command: String,
        explanation: String,
        risk: RiskLevel,
        alternatives: [String] = [],
        assumptions: [String] = []
    ) {
        self.command = command
        self.explanation = explanation
        self.risk = risk
        self.alternatives = alternatives
        self.assumptions = assumptions
    }
}

public enum SessionConnectionState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case reconnecting
    case disconnected
    case authExpired
    case failed(String)
}

public enum AWSTokenState: String, Codable, Sendable {
    case signedOut
    case signingIn
    case signedIn
    case expiringSoon
    case expired
    case failed
}

public struct AWSProfile: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var displayName: String
    public var accountHint: String?
    public var roleHint: String?
    public var defaultRegion: String
    public var tokenState: AWSTokenState

    public init(
        id: UUID = UUID(),
        displayName: String,
        accountHint: String? = nil,
        roleHint: String? = nil,
        defaultRegion: String,
        tokenState: AWSTokenState = .signedOut
    ) {
        self.id = id
        self.displayName = displayName
        self.accountHint = accountHint
        self.roleHint = roleHint
        self.defaultRegion = defaultRegion
        self.tokenState = tokenState
    }
}

public enum AskAIState: Equatable, Sendable {
    case idle
    case collectingPrompt
    case generating
    case generated(AIProposal)
    case validationFailed(String)
    case awaitingApproval(AIProposal)
    case executing(AIProposal)
    case completed(CommandRecord.ID)
    case failed(String)
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

public struct SSHConfigMetadata: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var alias: String
    public var hostname: String
    public var username: String
    public var port: Int
    public var linkedKeyLabel: String?
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        alias: String,
        hostname: String,
        username: String,
        port: Int = 22,
        linkedKeyLabel: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.alias = alias
        self.hostname = hostname
        self.username = username
        self.port = port
        self.linkedKeyLabel = linkedKeyLabel
        self.tags = tags
    }
}

public struct SSHKeyMetadata: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var label: String
    public var fingerprint: String
    public var algorithm: String
    public var source: String
    public var linkedEnvironmentIDs: [EnvironmentProfile.ID]
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        label: String,
        fingerprint: String,
        algorithm: String,
        source: String,
        linkedEnvironmentIDs: [EnvironmentProfile.ID] = [],
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.fingerprint = fingerprint
        self.algorithm = algorithm
        self.source = source
        self.linkedEnvironmentIDs = linkedEnvironmentIDs
        self.lastUsedAt = lastUsedAt
    }
}

public struct GPGKeyMetadata: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var label: String
    public var fingerprint: String
    public var capabilities: [String]
    public var usageNotes: String?

    public init(
        id: UUID = UUID(),
        label: String,
        fingerprint: String,
        capabilities: [String],
        usageNotes: String? = nil
    ) {
        self.id = id
        self.label = label
        self.fingerprint = fingerprint
        self.capabilities = capabilities
        self.usageNotes = usageNotes
    }
}
