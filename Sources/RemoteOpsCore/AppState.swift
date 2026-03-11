import Foundation

public struct RemoteOpsApp: Sendable {
    public private(set) var sessions: [Session]
    public private(set) var environments: [EnvironmentProfile]
    public private(set) var history: InMemoryHistoryStore
    public private(set) var selectedSessionID: Session.ID?
    public private(set) var selectedEnvironmentID: EnvironmentProfile.ID?
    public private(set) var awsProfiles: [AWSProfile]
    public private(set) var authProfiles: [AuthProfile]
    public private(set) var selectedAWSProfileID: AWSProfile.ID?
    public private(set) var selectedECSExecTarget: ECSExecTarget?
    public private(set) var sshConfigs: [SSHConfigMetadata]
    public private(set) var sshKeys: [SSHKeyMetadata]
    public private(set) var gpgKeys: [GPGKeyMetadata]

    private let aiProvider: AIProvider
    private let clipboardParser: ClipboardCommandParser
    private let riskClassifier: CommandRiskClassifier
    private let sessionValidator: SessionValidator
    private let aiModelSelector: AIModelSelector
    private let apiKeyStore: APIKeyStore
    private let ecsService: AWSECSService
    private let clock: Clock
    private let idGenerator: IDGenerator
    private let telemetry: TelemetrySink?

    public init(
        aiProvider: AIProvider = MockAIProvider(),
        clipboardParser: ClipboardCommandParser = ClipboardCommandParser(),
        riskClassifier: CommandRiskClassifier = CommandRiskClassifier(),
        sessionValidator: SessionValidator = SessionValidator(),
        aiModelSelector: AIModelSelector = AIModelSelector(),
        apiKeyStore: APIKeyStore = InMemoryAPIKeyStore(),
        ecsService: AWSECSService = MockAWSECSService(),
        clock: Clock = SystemClock(),
        idGenerator: IDGenerator = DefaultIDGenerator(),
        telemetry: TelemetrySink? = nil
    ) {
        self.sessions = []
        self.environments = []
        self.history = InMemoryHistoryStore(clock: clock)
        self.selectedSessionID = nil
        self.selectedEnvironmentID = nil
        self.awsProfiles = []
        self.authProfiles = []
        self.selectedAWSProfileID = nil
        self.selectedECSExecTarget = nil
        self.sshConfigs = []
        self.sshKeys = []
        self.gpgKeys = []
        self.aiProvider = aiProvider
        self.clipboardParser = clipboardParser
        self.riskClassifier = riskClassifier
        self.sessionValidator = sessionValidator
        self.aiModelSelector = aiModelSelector
        self.apiKeyStore = apiKeyStore
        self.ecsService = ecsService
        self.clock = clock
        self.idGenerator = idGenerator
        self.telemetry = telemetry
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
    public mutating func createSession(
        name: String,
        type: SessionType,
        host: String,
        port: Int = 22,
        username: String,
        tags: [String] = []
    ) throws -> Session.ID {
        try sessionValidator.validate(name: name, host: host, port: port, username: username)
        let session = Session(
            id: idGenerator.makeUUID(),
            name: name,
            type: type,
            host: host,
            port: port,
            username: username,
            tags: tags
        )
        return addSession(session)
    }

    public mutating func updateSession(_ session: Session) throws {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            throw RemoteOpsError.sessionNotFound
        }
        sessions[index] = session
    }

    @discardableResult
    public mutating func duplicateSession(id: Session.ID, named name: String? = nil) throws -> Session.ID {
        guard let session = sessions.first(where: { $0.id == id }) else {
            throw RemoteOpsError.sessionNotFound
        }

        let copy = Session(
            id: idGenerator.makeUUID(),
            name: name ?? "\(session.name) Copy",
            type: session.type,
            host: session.host,
            port: session.port,
            username: session.username,
            tags: session.tags,
            environmentIDs: [],
            isFavorite: session.isFavorite,
            isArchived: session.isArchived
        )
        return addSession(copy)
    }

    public mutating func setSessionFavorite(id: Session.ID, isFavorite: Bool) throws {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            throw RemoteOpsError.sessionNotFound
        }
        sessions[index].isFavorite = isFavorite
    }

    public mutating func setSessionArchived(id: Session.ID, isArchived: Bool) throws {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            throw RemoteOpsError.sessionNotFound
        }
        sessions[index].isArchived = isArchived
    }

    public mutating func deleteSession(id: Session.ID) {
        sessions.removeAll { $0.id == id }
        environments.removeAll { $0.sessionID == id }

        if selectedSessionID == id {
            selectedSessionID = sessions.first?.id
        }

        guard let selectedSessionID else {
            selectedEnvironmentID = nil
            return
        }

        selectedEnvironmentID = environments.first(where: { $0.sessionID == selectedSessionID })?.id
    }

    @discardableResult
    public mutating func addEnvironment(_ environment: EnvironmentProfile) -> EnvironmentProfile.ID {
        environments.append(environment)
        if selectedEnvironmentID == nil {
            selectedEnvironmentID = environment.id
        }
        if let sessionIndex = sessions.firstIndex(where: { $0.id == environment.sessionID }) {
            sessions[sessionIndex].environmentIDs.append(environment.id)
        }
        return environment.id
    }

    public mutating func updateEnvironment(_ environment: EnvironmentProfile) throws {
        guard let index = environments.firstIndex(where: { $0.id == environment.id }) else {
            throw RemoteOpsError.environmentNotFound
        }

        let priorSessionID = environments[index].sessionID
        environments[index] = environment

        if priorSessionID != environment.sessionID {
            if let oldSessionIndex = sessions.firstIndex(where: { $0.id == priorSessionID }) {
                sessions[oldSessionIndex].environmentIDs.removeAll { $0 == environment.id }
            }

            if let newSessionIndex = sessions.firstIndex(where: { $0.id == environment.sessionID }) {
                if !sessions[newSessionIndex].environmentIDs.contains(environment.id) {
                    sessions[newSessionIndex].environmentIDs.append(environment.id)
                }
            }
        }
    }

    public mutating func deleteEnvironment(id: EnvironmentProfile.ID) {
        guard let environment = environments.first(where: { $0.id == id }) else {
            return
        }

        environments.removeAll { $0.id == id }
        if let sessionIndex = sessions.firstIndex(where: { $0.id == environment.sessionID }) {
            sessions[sessionIndex].environmentIDs.removeAll { $0 == id }
        }

        if selectedEnvironmentID == id {
            selectedEnvironmentID = environments.first(where: { $0.sessionID == selectedSessionID })?.id
        }
    }

    public mutating func attachEnvironment(id: EnvironmentProfile.ID, to sessionID: Session.ID) throws {
        guard var environment = environments.first(where: { $0.id == id }) else {
            throw RemoteOpsError.environmentNotFound
        }

        environment.sessionID = sessionID
        try updateEnvironment(environment)
    }

    @discardableResult
    public mutating func cloneEnvironment(id: EnvironmentProfile.ID, named name: String? = nil) throws -> EnvironmentProfile.ID {
        guard let environment = environments.first(where: { $0.id == id }) else {
            throw RemoteOpsError.environmentNotFound
        }

        let clone = EnvironmentProfile(
            id: idGenerator.makeUUID(),
            name: name ?? "\(environment.name) Copy",
            sessionID: environment.sessionID,
            workingDirectory: environment.workingDirectory,
            shell: environment.shell,
            variables: environment.variables,
            label: environment.label,
            preferredAIProvider: environment.preferredAIProvider,
            preferredModel: environment.preferredModel,
            riskMode: environment.riskMode,
            notes: environment.notes,
            isFavorite: environment.isFavorite,
            tags: environment.tags
        )
        return addEnvironment(clone)
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
        try await askAI(intent: intent, privacyMode: .fullContext)
    }

    public func askAI(intent: String, privacyMode: PrivacyMode) async throws -> AIProposal {
        guard let session = currentSession else {
            throw RemoteOpsError.noSessionSelected
        }
        let environment = currentEnvironment

        let context = SessionContext(
            sessionName: session.name,
            environmentName: environment?.name,
            shell: environment?.shell ?? "/bin/bash"
        )

        let sanitizedIntent = sanitizeForPrivacy(intent, mode: privacyMode)
        return try await aiProvider.proposeCommand(intent: sanitizedIntent, context: context)
    }

    public mutating func run(command: String, source: CommandSource, risk: RiskLevel) throws {
        guard let sessionID = selectedSessionID else {
            throw RemoteOpsError.noSessionSelected
        }

        let record = CommandRecord(
            id: idGenerator.makeUUID(),
            timestamp: clock.now,
            sessionID: sessionID,
            environmentID: selectedEnvironmentID,
            command: command,
            source: source,
            risk: risk
        )
        history.append(record)
    }

    public mutating func runAICommand(prompt: String, proposal: AIProposal, editedCommand: String? = nil) throws {
        let commandToRun = editedCommand ?? proposal.command
        let wasEdited = editedCommand != nil && editedCommand != proposal.command

        guard let sessionID = selectedSessionID else {
            throw RemoteOpsError.noSessionSelected
        }

        let record = CommandRecord(
            id: idGenerator.makeUUID(),
            timestamp: clock.now,
            sessionID: sessionID,
            environmentID: selectedEnvironmentID,
            command: commandToRun,
            source: .askAI,
            risk: riskClassifier.classify(command: commandToRun),
            nlPrompt: prompt,
            wasEdited: wasEdited
        )
        history.append(record)
    }

    public mutating func runHistoryCommand(recordID: CommandRecord.ID, editedCommand: String? = nil) throws {
        guard let prior = history.records.first(where: { $0.id == recordID }) else {
            throw RemoteOpsError.historyEntryNotFound
        }

        let commandToRun = editedCommand ?? prior.command
        let wasEdited = editedCommand != nil && editedCommand != prior.command
        try run(command: commandToRun, source: .history, risk: riskClassifier.classify(command: commandToRun))
        telemetry?.record(event: "history.rerun", metadata: ["edited": String(wasEdited)])

        guard wasEdited, let newestID = history.records.last?.id else {
            return
        }
        history.setEdited(id: newestID, wasEdited: true)
    }

    public mutating func run(command: String, source: CommandSource) throws {
        try run(command: command, source: source, risk: riskClassifier.classify(command: command))
        telemetry?.record(event: "command.executed", metadata: ["source": source.rawValue])
    }

    public static func fullMock() -> RemoteOpsApp {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(
            Session(name: "Mock Prod", type: .ssh, host: "mock.internal", username: "ops")
        )
        _ = app.addEnvironment(
            EnvironmentProfile(name: "Production", sessionID: sessionID, label: .production, isFavorite: true)
        )
        try? app.run(command: "df -h", source: .askAI)
        _ = app.upsertAWSProfile(
            AWSProfile(displayName: "Mock AWS", accountHint: "123456789012", defaultRegion: "us-east-1", tokenState: .signedIn)
        )
        return app
    }

    public func requiresAdditionalConfirmation(for command: String) -> Bool {
        let risk = riskClassifier.classify(command: command)
        if risk == .high {
            return true
        }

        guard currentEnvironment?.label == .production else {
            return false
        }

        return risk != .low
    }

    public func validateExecutionApproval(command: String, typedConfirmation: String?) throws {
        guard requiresAdditionalConfirmation(for: command) else {
            return
        }

        guard currentEnvironment?.label == .production, riskClassifier.classify(command: command) == .high else {
            return
        }

        let expected = currentEnvironment?.name ?? ""
        if typedConfirmation?.trimmingCharacters(in: .whitespacesAndNewlines) != expected {
            throw RemoteOpsError.productionConfirmationMismatch(expected: expected)
        }
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

    public mutating func pinHistoryEntry(id: CommandRecord.ID, pinned: Bool) {
        history.pin(id: id, pinned: pinned)
    }

    public mutating func tagHistoryEntry(id: CommandRecord.ID, tags: [String]) {
        history.setTags(id: id, tags: tags)
    }

    public mutating func hardDeleteHistoryEntry(id: CommandRecord.ID) {
        history.hardDelete(id: id)
    }

    public func searchHistory(scope: HistoryScope = .global, query: HistoryQuery = HistoryQuery()) -> [CommandRecord] {
        history.search(scope: scope, query: query)
    }

    public func filteredEnvironments(_ filter: EnvironmentFilter = EnvironmentFilter()) -> [EnvironmentProfile] {
        environments.filter { environment in
            if let label = filter.label, environment.label != label {
                return false
            }
            if let tag = filter.tag, !environment.tags.contains(tag) {
                return false
            }
            if filter.favoritesOnly, !environment.isFavorite {
                return false
            }
            return true
        }
    }

    public func resolveAIModel(preferred: String, availableModels: [String], defaultModel: String) throws -> String {
        try aiModelSelector.resolveModel(preferred: preferred, availableModels: availableModels, fallback: defaultModel)
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



    @discardableResult
    public mutating func upsertAWSProfile(_ profile: AWSProfile) -> AWSProfile.ID {
        if let index = awsProfiles.firstIndex(where: { $0.id == profile.id }) {
            awsProfiles[index] = profile
        } else {
            awsProfiles.append(profile)
        }

        if selectedAWSProfileID == nil {
            selectedAWSProfileID = profile.id
        }
        return profile.id
    }

    public mutating func selectAWSProfile(id: AWSProfile.ID?) {
        selectedAWSProfileID = id
    }

    @discardableResult
    public mutating func upsertAuthProfile(_ profile: AuthProfile) -> AuthProfile.ID {
        if let index = authProfiles.firstIndex(where: { $0.id == profile.id }) {
            authProfiles[index] = profile
        } else {
            authProfiles.append(profile)
        }
        return profile.id
    }

    public mutating func deleteAuthProfile(id: AuthProfile.ID) {
        authProfiles.removeAll { $0.id == id }
    }

    public func currentAWSProfile() -> AWSProfile? {
        guard let selectedAWSProfileID else { return nil }
        return awsProfiles.first(where: { $0.id == selectedAWSProfileID })
    }

    public mutating func resolveECSTarget(
        region: String,
        service: String? = nil,
        preferredCluster: String? = nil,
        preferredService: String? = nil,
        preferredTask: String? = nil,
        preferredContainer: String? = nil
    ) async throws -> ECSExecTarget {
        guard let profile = currentAWSProfile() else {
            throw RemoteOpsError.awsProfileNotFound
        }

        let clusters = try await ecsService.clusters(profile: profile, region: region)
        guard let cluster = preferredCluster ?? clusters.first else {
            throw RemoteOpsError.noECSTargetsAvailable
        }

        let discoveredServices = try await ecsService.services(profile: profile, region: region, cluster: cluster)
        let selectedService = service ?? preferredService ?? discoveredServices.first

        let tasks = try await ecsService.tasks(profile: profile, region: region, cluster: cluster, service: selectedService)
        guard let task = preferredTask ?? tasks.first else {
            throw RemoteOpsError.noECSTargetsAvailable
        }

        let containers = try await ecsService.containers(profile: profile, region: region, cluster: cluster, task: task)
        guard let container = preferredContainer ?? containers.first else {
            throw RemoteOpsError.noECSTargetsAvailable
        }

        let target = ECSExecTarget(
            awsProfileID: profile.id,
            region: region,
            cluster: cluster,
            service: selectedService,
            task: task,
            container: container
        )
        selectedECSExecTarget = target
        return target
    }

    public mutating func upsertSSHConfig(_ config: SSHConfigMetadata) {
        if let index = sshConfigs.firstIndex(where: { $0.id == config.id }) {
            sshConfigs[index] = config
        } else {
            sshConfigs.append(config)
        }
    }

    public mutating func upsertSSHKey(_ key: SSHKeyMetadata) {
        if let index = sshKeys.firstIndex(where: { $0.id == key.id }) {
            sshKeys[index] = key
        } else {
            sshKeys.append(key)
        }
    }

    public mutating func upsertGPGKey(_ key: GPGKeyMetadata) {
        if let index = gpgKeys.firstIndex(where: { $0.id == key.id }) {
            gpgKeys[index] = key
        } else {
            gpgKeys.append(key)
        }
    }

    public func browseSSHConfigs(searchText: String? = nil) -> [SSHConfigMetadata] {
        filterMetadata(sshConfigs, searchText: searchText) {
            [$0.alias, $0.hostname, $0.username] + $0.tags
        }
    }

    public func browseSSHKeys(searchText: String? = nil) -> [SSHKeyMetadata] {
        filterMetadata(sshKeys, searchText: searchText) {
            [$0.label, $0.fingerprint, $0.algorithm, $0.source]
        }
    }

    public func browseGPGKeys(searchText: String? = nil) -> [GPGKeyMetadata] {
        filterMetadata(gpgKeys, searchText: searchText) {
            [$0.label, $0.fingerprint] + $0.capabilities + [$0.usageNotes ?? ""]
        }
    }

    private func filterMetadata<T>(_ values: [T], searchText: String?, fields: (T) -> [String]) -> [T] {
        guard let searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return values
        }

        let query = searchText.lowercased()
        return values.filter { value in
            fields(value).contains { $0.lowercased().contains(query) }
        }
    }

    private func sanitizeForPrivacy(_ intent: String, mode: PrivacyMode) -> String {
        switch mode {
        case .fullContext:
            return intent
        case .minimalContext:
            return intent.replacingOccurrences(of: "token", with: "[REDACTED_TOKEN]", options: .caseInsensitive)
        case .noHistoryContext:
            return intent + "\nContext: ignore prior command history."
        case .noOutputUpload:
            return intent + "\nContext: do not rely on command output logs."
        }
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
    case sessionNotFound
    case environmentNotFound
    case awsProfileNotFound
    case noECSTargetsAvailable
    case historyEntryNotFound
    case productionConfirmationMismatch(expected: String)
}
