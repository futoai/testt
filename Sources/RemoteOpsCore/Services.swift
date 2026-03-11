import Foundation
#if canImport(Security)
import Security
#endif

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
                alternatives: ["du -sh *"],
                assumptions: ["GNU coreutils-compatible df is available."]
            )
        }

        if lower.contains("restart") || lower.contains("delete") || lower.contains("drop") {
            return AIProposal(
                command: "sudo systemctl restart app.service",
                explanation: "Restarts the main application service.",
                risk: .high,
                alternatives: ["systemctl status app.service"],
                assumptions: ["User has sudo privileges on the remote host."]
            )
        }

        return AIProposal(
            command: "ls -la",
            explanation: "Lists files including hidden entries for quick inspection.",
            risk: .low,
            alternatives: ["pwd", "whoami"],
            assumptions: ["Current shell is POSIX-like."]
        )
    }
}



public enum PrivacyMode: String, Codable, Sendable {
    case fullContext
    case minimalContext
    case noHistoryContext
    case noOutputUpload
}

public struct SessionConnectionStateMachine: Sendable {
    public private(set) var state: SessionConnectionState

    public init(initialState: SessionConnectionState = .idle) {
        self.state = initialState
    }

    public mutating func startConnection() {
        state = .connecting
    }

    public mutating func connectionSucceeded() {
        state = .connected
    }

    public mutating func connectionFailed(_ message: String) {
        state = .failed(message)
    }

    public mutating func disconnect() {
        state = .disconnected
    }

    public mutating func startReconnect() {
        state = .reconnecting
    }

    public mutating func authExpired() {
        state = .authExpired
    }
}

public struct AskAIStateMachine: Sendable {
    public private(set) var state: AskAIState

    public init(initialState: AskAIState = .idle) {
        self.state = initialState
    }

    public mutating func beginPromptEntry() {
        state = .collectingPrompt
    }

    public mutating func generate() {
        state = .generating
    }

    public mutating func generated(_ proposal: AIProposal) {
        state = .generated(proposal)
    }

    public mutating func awaitApproval(_ proposal: AIProposal) {
        state = .awaitingApproval(proposal)
    }

    public mutating func execute(_ proposal: AIProposal) {
        state = .executing(proposal)
    }

    public mutating func complete(recordID: CommandRecord.ID) {
        state = .completed(recordID)
    }

    public mutating func validationFailed(_ message: String) {
        state = .validationFailed(message)
    }

    public mutating func fail(_ message: String) {
        state = .failed(message)
    }

    public mutating func reset() {
        state = .idle
    }
}

public enum HistoryScope: Sendable {
    case session(Session.ID)
    case environment(EnvironmentProfile.ID)
    case global
}

public struct HistoryQuery: Sendable {
    public var text: String?
    public var source: CommandSource?
    public var risk: RiskLevel?
    public var tag: String?
    public var includeDeleted: Bool

    public init(
        text: String? = nil,
        source: CommandSource? = nil,
        risk: RiskLevel? = nil,
        tag: String? = nil,
        includeDeleted: Bool = false
    ) {
        self.text = text
        self.source = source
        self.risk = risk
        self.tag = tag
        self.includeDeleted = includeDeleted
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

    public mutating func setTags(id: CommandRecord.ID, tags: [String]) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].tags = tags
    }

    public mutating func setEdited(id: CommandRecord.ID, wasEdited: Bool) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].wasEdited = wasEdited
    }

    public mutating func hardDelete(id: CommandRecord.ID) {
        records.removeAll { $0.id == id }
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

    public func environmentHistory(environmentID: EnvironmentProfile.ID, includeDeleted: Bool = false) -> [CommandRecord] {
        records
            .filter { $0.environmentID == environmentID }
            .filter { includeDeleted || $0.deletedAt == nil }
            .sorted { $0.timestamp > $1.timestamp }
    }

    public func search(scope: HistoryScope, query: HistoryQuery = HistoryQuery()) -> [CommandRecord] {
        let base: [CommandRecord] = switch scope {
        case let .session(sessionID):
            sessionHistory(sessionID: sessionID, includeDeleted: query.includeDeleted)
        case let .environment(environmentID):
            environmentHistory(environmentID: environmentID, includeDeleted: query.includeDeleted)
        case .global:
            globalHistory(includeDeleted: query.includeDeleted)
        }

        return base.filter { record in
            if let text = query.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                let needle = text.lowercased()
                let matchesCommand = record.command.lowercased().contains(needle)
                let matchesPrompt = record.nlPrompt?.lowercased().contains(needle) ?? false
                if !matchesCommand && !matchesPrompt {
                    return false
                }
            }

            if let source = query.source, record.source != source {
                return false
            }

            if let risk = query.risk, record.risk != risk {
                return false
            }

            if let tag = query.tag, !record.tags.contains(tag) {
                return false
            }

            return true
        }
    }
}


public struct ECSExecTarget: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var awsProfileID: AWSProfile.ID
    public var region: String
    public var cluster: String
    public var service: String?
    public var task: String
    public var container: String

    public init(
        id: UUID = UUID(),
        awsProfileID: AWSProfile.ID,
        region: String,
        cluster: String,
        service: String? = nil,
        task: String,
        container: String
    ) {
        self.id = id
        self.awsProfileID = awsProfileID
        self.region = region
        self.cluster = cluster
        self.service = service
        self.task = task
        self.container = container
    }
}

public protocol AWSECSService: Sendable {
    func clusters(profile: AWSProfile, region: String) async throws -> [String]
    func services(profile: AWSProfile, region: String, cluster: String) async throws -> [String]
    func tasks(profile: AWSProfile, region: String, cluster: String, service: String?) async throws -> [String]
    func containers(profile: AWSProfile, region: String, cluster: String, task: String) async throws -> [String]
}

public struct MockAWSECSService: AWSECSService {
    public init() {}

    public func clusters(profile: AWSProfile, region: String) async throws -> [String] {
        ["core-cluster", "batch-cluster"]
    }

    public func services(profile: AWSProfile, region: String, cluster: String) async throws -> [String] {
        switch cluster {
        case "core-cluster":
            return ["api", "worker"]
        case "batch-cluster":
            return ["batch-jobs"]
        default:
            return []
        }
    }

    public func tasks(profile: AWSProfile, region: String, cluster: String, service: String?) async throws -> [String] {
        ["task-001", "task-002"]
    }

    public func containers(profile: AWSProfile, region: String, cluster: String, task: String) async throws -> [String] {
        ["app", "sidecar"]
    }
}

public enum ECSSelectionState: Equatable, Sendable {
    case idle
    case loadingClusters
    case selectingCluster([String])
    case loadingServices(cluster: String)
    case selectingService(cluster: String, services: [String])
    case loadingTasks(cluster: String)
    case selectingTask(cluster: String, tasks: [String])
    case loadingContainers(cluster: String, task: String)
    case selectingContainer(cluster: String, task: String, containers: [String])
    case ready(ECSExecTarget)
    case failed(String)
}

public struct ECSSelectionStateMachine: Sendable {
    public private(set) var state: ECSSelectionState

    public init(initialState: ECSSelectionState = .idle) {
        self.state = initialState
    }

    public mutating func startClusterLoad() {
        state = .loadingClusters
    }

    public mutating func clustersLoaded(_ clusters: [String]) {
        state = .selectingCluster(clusters)
    }

    public mutating func startTaskLoad(cluster: String) {
        state = .loadingTasks(cluster: cluster)
    }

    public mutating func startServiceLoad(cluster: String) {
        state = .loadingServices(cluster: cluster)
    }

    public mutating func servicesLoaded(cluster: String, services: [String]) {
        state = .selectingService(cluster: cluster, services: services)
    }

    public mutating func tasksLoaded(cluster: String, tasks: [String]) {
        state = .selectingTask(cluster: cluster, tasks: tasks)
    }

    public mutating func startContainerLoad(cluster: String, task: String) {
        state = .loadingContainers(cluster: cluster, task: task)
    }

    public mutating func containersLoaded(cluster: String, task: String, containers: [String]) {
        state = .selectingContainer(cluster: cluster, task: task, containers: containers)
    }

    public mutating func complete(target: ECSExecTarget) {
        state = .ready(target)
    }

    public mutating func fail(_ message: String) {
        state = .failed(message)
    }

    public mutating func reset() {
        state = .idle
    }
}

public struct EnvironmentFilter: Sendable {
    public var label: EnvironmentLabel?
    public var tag: String?
    public var favoritesOnly: Bool

    public init(label: EnvironmentLabel? = nil, tag: String? = nil, favoritesOnly: Bool = false) {
        self.label = label
        self.tag = tag
        self.favoritesOnly = favoritesOnly
    }
}

public enum AWSAuthState: Equatable, Sendable {
    case signedOut
    case signingIn
    case signedIn
    case expiringSoon
    case expired
    case failed(String)
}

public struct AWSAuthStateMachine: Sendable {
    public private(set) var state: AWSAuthState

    public init(initialState: AWSAuthState = .signedOut) {
        self.state = initialState
    }

    public mutating func startSignIn() { state = .signingIn }
    public mutating func signInSucceeded() { state = .signedIn }
    public mutating func setExpiringSoon() { state = .expiringSoon }
    public mutating func expire() { state = .expired }
    public mutating func signOut() { state = .signedOut }
    public mutating func fail(_ message: String) { state = .failed(message) }
}

public struct CommandRiskClassifier: Sendable {
    private static let highRiskTokens = [
        "rm -rf", "mkfs", "dd if=", "shutdown", "reboot", "poweroff", "drop table",
        "truncate table", "chmod 777", "chown -r", "systemctl stop", "kill -9", "terraform destroy"
    ]

    private static let mediumRiskTokens = [
        "sudo", "systemctl restart", "kubectl delete", "docker rm", "helm uninstall", "iptables"
    ]

    public init() {}

    public func classify(command: String) -> RiskLevel {
        let normalized = command.lowercased()

        if Self.highRiskTokens.contains(where: { normalized.contains($0) }) {
            return .high
        }

        if Self.mediumRiskTokens.contains(where: { normalized.contains($0) }) {
            return .medium
        }

        return .low
    }
}

public enum ValidationError: Error, Equatable {
    case emptyName
    case invalidHost
    case invalidPort
    case emptyUsername
    case unsupportedModel(String)
}

public struct SessionValidator: Sendable {
    public init() {}

    public func validate(name: String, host: String, port: Int, username: String) throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyName
        }

        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedHost.isEmpty || normalizedHost.contains(" ") || normalizedHost.contains("/") {
            throw ValidationError.invalidHost
        }

        if port < 1 || port > 65_535 {
            throw ValidationError.invalidPort
        }

        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyUsername
        }
    }
}

public struct AIModelSelector: Sendable {
    public init() {}

    public func resolveModel(
        preferred preferredModel: String,
        availableModels: [String],
        fallback defaultModel: String
    ) throws -> String {
        if availableModels.contains(preferredModel) {
            return preferredModel
        }

        if availableModels.contains(defaultModel) {
            return defaultModel
        }

        if let first = availableModels.first {
            return first
        }

        throw ValidationError.unsupportedModel(preferredModel)
    }
}

public struct ClipboardCommandParser: Sendable {
    private let classifier: CommandRiskClassifier

    public init(classifier: CommandRiskClassifier = CommandRiskClassifier()) {
        self.classifier = classifier
    }

    public func parse(_ text: String) -> ClipboardReview? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let command = firstLineWithoutPromptPrefix(trimmed)
        guard !command.isEmpty else { return nil }

        guard looksLikeCommand(command) || trimmed.contains("\n") else { return nil }
        let risk = classifier.classify(command: command)
        var warnings: [String] = []
        if risk == .high {
            warnings.append("Potentially destructive command. Review carefully before running.")
        }
        if command.contains("$AWS_") || command.contains("token") || command.contains("password") {
            warnings.append("Command may contain sensitive material.")
        }

        return ClipboardReview(originalText: text, command: command, risk: risk, warnings: warnings)
    }

    private func looksLikeCommand(_ text: String) -> Bool {
        if text.contains("\n") {
            return true
        }

        let commandPrefixes = [
            "sudo ", "ssh ", "kubectl ", "docker ", "aws ", "git ", "ls", "cd ", "cat ", "tail ",
            "journalctl", "systemctl", "ps ", "top", "du ", "df ", "rm "
        ]
        if commandPrefixes.contains(where: { text.lowercased().hasPrefix($0) }) {
            return true
        }

        return text.contains("|") || text.contains("&&") || text.contains(";")
    }

    private func firstLineWithoutPromptPrefix(_ text: String) -> String {
        let firstLine = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if let dollarIndex = trimmed.firstIndex(of: "$") {
            let afterDollar = trimmed.index(after: dollarIndex)
            return String(trimmed[afterDollar...]).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}

public protocol APIKeyStore: Sendable {
    func save(apiKey: String, for provider: String) throws
    func loadAPIKey(for provider: String) throws -> String?
    func deleteAPIKey(for provider: String) throws
}

public enum APIKeyStoreError: Error, Equatable {
    case failedToStore
    case failedToRead
    case failedToDelete
}

public final class InMemoryAPIKeyStore: APIKeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    public init() {}

    public func save(apiKey: String, for provider: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[provider] = apiKey
    }

    public func loadAPIKey(for provider: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[provider]
    }

    public func deleteAPIKey(for provider: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: provider)
    }
}

#if canImport(Security)
public struct KeychainAPIKeyStore: APIKeyStore, Sendable {
    private let service: String

    public init(service: String = "RemoteOpsCore.APIKeys") {
        self.service = service
    }

    public func save(apiKey: String, for provider: String) throws {
        let data = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider
        ]

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw APIKeyStoreError.failedToStore }
    }

    public func loadAPIKey(for provider: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw APIKeyStoreError.failedToRead }
        guard let data = result as? Data else { throw APIKeyStoreError.failedToRead }
        return String(data: data, encoding: .utf8)
    }

    public func deleteAPIKey(for provider: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.failedToDelete
        }
    }
}
#endif
