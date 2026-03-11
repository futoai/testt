import Foundation

public protocol AIProvider: Sendable {
    func proposeCommand(intent: String, context: SessionContext) async throws -> AIProposal
}

public struct SessionContext: Sendable {
    public var sessionName: String
    public var environmentName: String?
    public var shell: String

    public init(sessionName: String, environmentName: String?, shell: String) {
        self.sessionName = sessionName
        self.environmentName = environmentName
        self.shell = shell
    }
}

public struct MockAIProvider: AIProvider {
    public init() {}

    public func proposeCommand(intent: String, context: SessionContext) async throws -> AIProposal {
        let lower = intent.lowercased()

        if lower.contains("disk") {
            return AIProposal(
                command: "df -h",
                explanation: "Shows disk usage in human-readable format.",
                risk: .low,
                alternatives: ["du -sh *"]
            )
        }

        if lower.contains("restart") || lower.contains("delete") || lower.contains("drop") {
            return AIProposal(
                command: "sudo systemctl restart app.service",
                explanation: "Restarts the main application service.",
                risk: .high,
                alternatives: ["systemctl status app.service"]
            )
        }

        return AIProposal(
            command: "ls -la",
            explanation: "Lists files including hidden entries for quick inspection.",
            risk: .low,
            alternatives: ["pwd", "whoami"]
        )
    }
}

public struct InMemoryHistoryStore: Sendable {
    private(set) var records: [CommandRecord] = []

    public init() {}

    public mutating func append(_ record: CommandRecord) {
        records.append(record)
    }

    public mutating func softDelete(id: CommandRecord.ID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].deletedAt = Date()
    }

    public mutating func restore(id: CommandRecord.ID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].deletedAt = nil
    }

    public mutating func pin(id: CommandRecord.ID, pinned: Bool) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].pinned = pinned
    }

    public func sessionHistory(sessionID: Session.ID, includeDeleted: Bool = false) -> [CommandRecord] {
        records
            .filter { $0.sessionID == sessionID }
            .filter { includeDeleted || $0.deletedAt == nil }
            .sorted { $0.timestamp > $1.timestamp }
    }

    public func globalHistory(includeDeleted: Bool = false) -> [CommandRecord] {
        records
            .filter { includeDeleted || $0.deletedAt == nil }
            .sorted { $0.timestamp > $1.timestamp }
    }
}
