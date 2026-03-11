import Foundation

public struct RemoteOpsApp: Sendable {
    public private(set) var sessions: [Session]
    public private(set) var environments: [EnvironmentProfile]
    public private(set) var history: InMemoryHistoryStore
    public private(set) var selectedSessionID: Session.ID?
    public private(set) var selectedEnvironmentID: EnvironmentProfile.ID?

    private let aiProvider: AIProvider

    public init(aiProvider: AIProvider = MockAIProvider()) {
        self.sessions = []
        self.environments = []
        self.history = InMemoryHistoryStore()
        self.selectedSessionID = nil
        self.selectedEnvironmentID = nil
        self.aiProvider = aiProvider
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
}
