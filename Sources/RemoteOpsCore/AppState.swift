import Foundation

public struct RemoteOpsApp: Sendable {
    public private(set) var sessions: [Session]
    public private(set) var environments: [EnvironmentProfile]
    public private(set) var history: InMemoryHistoryStore
    public private(set) var selectedSessionID: Session.ID?
    public private(set) var selectedEnvironmentID: EnvironmentProfile.ID?

    private let aiProvider: AIProvider
    private let clipboardParser: ClipboardCommandParser
    private let riskClassifier: CommandRiskClassifier
    private let apiKeyStore: APIKeyStore

    public init(
        aiProvider: AIProvider = MockAIProvider(),
        clipboardParser: ClipboardCommandParser = ClipboardCommandParser(),
        riskClassifier: CommandRiskClassifier = CommandRiskClassifier(),
        apiKeyStore: APIKeyStore = InMemoryAPIKeyStore()
    ) {
        self.sessions = []
        self.environments = []
        self.history = InMemoryHistoryStore()
        self.selectedSessionID = nil
        self.selectedEnvironmentID = nil
        self.aiProvider = aiProvider
        self.clipboardParser = clipboardParser
        self.riskClassifier = riskClassifier
        self.apiKeyStore = apiKeyStore
    }

    @discardableResult
    public mutating func addSession(_ session: Session) -> Session.ID {
        sessions.append(session)
        if selectedSessionID == nil {
            selectedSessionID = session.id
        }
        return session.id
    }

    @discardableResult
    public mutating func addEnvironment(_ environment: EnvironmentProfile) -> EnvironmentProfile.ID {
        environments.append(environment)
        if selectedEnvironmentID == nil {
            selectedEnvironmentID = environment.id
        }
        return environment.id
    }

    public mutating func selectSession(id: Session.ID) {
        selectedSessionID = id
        if let env = environments.first(where: { $0.sessionID == id }) {
            selectedEnvironmentID = env.id
        } else {
            selectedEnvironmentID = nil
        }
    }

    public mutating func selectEnvironment(id: EnvironmentProfile.ID?) {
        selectedEnvironmentID = id
    }

    public func askAI(intent: String) async throws -> AIProposal {
        guard let session = currentSession else {
            throw RemoteOpsError.noSessionSelected
        }
        let environment = currentEnvironment

        let context = SessionContext(
            sessionName: session.name,
            environmentName: environment?.name,
            shell: environment?.shell ?? "/bin/bash"
        )
        return try await aiProvider.proposeCommand(intent: intent, context: context)
    }

    public mutating func run(command: String, source: CommandSource, risk: RiskLevel) throws {
        guard let sessionID = selectedSessionID else {
            throw RemoteOpsError.noSessionSelected
        }

        let record = CommandRecord(
            sessionID: sessionID,
            environmentID: selectedEnvironmentID,
            command: command,
            source: source,
            risk: risk
        )
        history.append(record)
    }

    public mutating func run(command: String, source: CommandSource) throws {
        try run(command: command, source: source, risk: riskClassifier.classify(command: command))
    }

    public func reviewClipboard(_ text: String) -> ClipboardReview? {
        clipboardParser.parse(text)
    }

    public mutating func runClipboardCommand(_ text: String) throws {
        guard let review = reviewClipboard(text) else {
            throw RemoteOpsError.clipboardDidNotContainCommand
        }
        try run(command: review.command, source: .paste, risk: review.risk)
    }

    public func sessionHistory() throws -> [CommandRecord] {
        guard let selectedSessionID else {
            throw RemoteOpsError.noSessionSelected
        }
        return history.sessionHistory(sessionID: selectedSessionID)
    }

    public func environmentHistory() throws -> [CommandRecord] {
        guard let selectedEnvironmentID else {
            throw RemoteOpsError.noEnvironmentSelected
        }
        return history.environmentHistory(environmentID: selectedEnvironmentID)
    }

    public func globalHistory() -> [CommandRecord] {
        history.globalHistory()
    }

    public mutating func deleteHistoryEntry(id: CommandRecord.ID) {
        history.softDelete(id: id)
    }

    public mutating func restoreHistoryEntry(id: CommandRecord.ID) {
        history.restore(id: id)
    }

    public func saveProviderAPIKey(_ apiKey: String, provider: String) throws {
        try apiKeyStore.save(apiKey: apiKey, for: provider)
    }

    public func providerAPIKey(provider: String) throws -> String? {
        try apiKeyStore.loadAPIKey(for: provider)
    }

    public func deleteProviderAPIKey(provider: String) throws {
        try apiKeyStore.deleteAPIKey(for: provider)
    }

    public var currentSession: Session? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    public var currentEnvironment: EnvironmentProfile? {
        guard let selectedEnvironmentID else { return nil }
        return environments.first { $0.id == selectedEnvironmentID }
    }
}

public enum RemoteOpsError: Error, Equatable {
    case noSessionSelected
    case noEnvironmentSelected
    case clipboardDidNotContainCommand
}
