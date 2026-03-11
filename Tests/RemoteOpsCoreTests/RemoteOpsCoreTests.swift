import Foundation
import Testing
@testable import RemoteOpsCore

struct RemoteOpsCoreTests {
    @Test
    func askAIUsesMockProvider() async throws {
        var app = RemoteOpsApp()
        _ = app.addSession(Session(name: "s", type: .ssh, host: "localhost", username: "me"))

        let proposal = try await app.askAI(intent: "check disk usage")

        #expect(proposal.command == "df -h")
        #expect(proposal.risk == .low)
    }

    @Test
    func runCommandAppendsHistory() throws {
        var app = RemoteOpsApp()
        let sessionID = try app.createSession(name: "s", type: .ssh, host: "localhost", username: "me")

        try app.run(command: "ls -la", source: .typed)

        let history = app.history.sessionHistory(sessionID: sessionID)
        #expect(history.count == 1)
        #expect(history[0].command == "ls -la")
    }

    @Test
    func historySoftDeleteAndRestore() {
        var store = InMemoryHistoryStore()
        let sessionID = Session(name: "s", type: .ssh, host: "localhost", username: "me").id
        let record = CommandRecord(sessionID: sessionID, command: "rm -rf /tmp/old", source: .paste, risk: .high)
        store.append(record)

        store.softDelete(id: record.id)
        #expect(store.globalHistory().isEmpty)

        store.restore(id: record.id)
        #expect(store.globalHistory().count == 1)
    }

    @Test
    func clipboardReviewAndRunFlow() throws {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(Session(name: "prod", type: .ssh, host: "prod.internal", username: "ubuntu"))

        let review = try #require(app.reviewClipboard("$ rm -rf /tmp/stale-cache"))
        #expect(review.command == "rm -rf /tmp/stale-cache")
        #expect(review.risk == .high)
        #expect(review.warnings.isEmpty == false)

        try app.runClipboardCommand("$ rm -rf /tmp/stale-cache")
        let history = app.history.sessionHistory(sessionID: sessionID)
        #expect(history.count == 1)
        #expect(history[0].source == .paste)
        #expect(history[0].risk == .high)
    }

    @Test
    func canQuerySessionEnvironmentAndGlobalHistory() throws {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(Session(name: "prod", type: .ssh, host: "prod.internal", username: "ubuntu"))
        let environmentID = app.addEnvironment(EnvironmentProfile(name: "production", sessionID: sessionID))
        app.selectSession(id: sessionID)
        app.selectEnvironment(id: environmentID)

        try app.run(command: "sudo systemctl restart api", source: .typed)
        try app.run(command: "df -h", source: .askAI)

        #expect(try app.sessionHistory().count == 2)
        #expect(try app.environmentHistory().count == 2)
        #expect(app.globalHistory().count == 2)
    }

    @Test
    func apiKeysCanBeStoredLoadedAndDeleted() throws {
        let keyStore = InMemoryAPIKeyStore()
        let app = RemoteOpsApp(apiKeyStore: keyStore)

        try app.saveProviderAPIKey("sk-test-123", provider: "openrouter")
        #expect(try app.providerAPIKey(provider: "openrouter") == "sk-test-123")

        try app.deleteProviderAPIKey(provider: "openrouter")
        #expect(try app.providerAPIKey(provider: "openrouter") == nil)
    }

    @Test
    func duplicateAndArchiveSessionWorkflow() throws {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(Session(name: "prod", type: .awsECSExec, host: "cluster", username: "ecs-user"))

        try app.setSessionFavorite(id: sessionID, isFavorite: true)
        try app.setSessionArchived(id: sessionID, isArchived: true)
        let copyID = try app.duplicateSession(id: sessionID)

        #expect(app.sessions.count == 2)
        #expect(app.sessions.first(where: { $0.id == sessionID })?.isFavorite == true)
        #expect(app.sessions.first(where: { $0.id == sessionID })?.isArchived == true)
        #expect(app.sessions.contains(where: { $0.id == copyID }))
    }

    @Test
    func cloneEnvironmentAndProductionConfirmationRules() throws {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(Session(name: "prod", type: .ssh, host: "prod.internal", username: "ubuntu"))
        let envID = app.addEnvironment(
            EnvironmentProfile(
                name: "production",
                sessionID: sessionID,
                label: .production,
                preferredAIProvider: "openrouter",
                riskMode: .strict
            )
        )

        let clonedID = try app.cloneEnvironment(id: envID)
        app.selectEnvironment(id: envID)

        #expect(app.environments.count == 2)
        #expect(app.environments.contains(where: { $0.id == clonedID }))
        #expect(app.requiresAdditionalConfirmation(for: "sudo systemctl restart app") == true)
        #expect(app.requiresAdditionalConfirmation(for: "pwd") == false)
    }

    @Test
    func updateDeleteAndAttachEnvironmentWorkflows() throws {
        var app = RemoteOpsApp(idGenerator: IncrementingIDGenerator())
        let sessionA = try app.createSession(name: "a", type: .ssh, host: "a.internal", username: "ops")
        let sessionB = try app.createSession(name: "b", type: .ssh, host: "b.internal", username: "ops")
        let envID = app.addEnvironment(EnvironmentProfile(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!, name: "dev", sessionID: sessionA))

        var updated = try #require(app.environments.first(where: { $0.id == envID }))
        updated.name = "development"
        try app.updateEnvironment(updated)
        #expect(app.environments.first(where: { $0.id == envID })?.name == "development")

        try app.attachEnvironment(id: envID, to: sessionB)
        #expect(app.environments.first(where: { $0.id == envID })?.sessionID == sessionB)
        #expect(app.sessions.first(where: { $0.id == sessionA })?.environmentIDs.contains(envID) == false)
        #expect(app.sessions.first(where: { $0.id == sessionB })?.environmentIDs.contains(envID) == true)

        app.selectSession(id: sessionB)
        app.selectEnvironment(id: envID)
        app.deleteEnvironment(id: envID)
        #expect(app.environments.contains(where: { $0.id == envID }) == false)
        #expect(app.selectedEnvironmentID == nil)
    }



    @Test
    func sessionStoresLastConnectedAtMetadata() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = Session(
            name: "prod",
            type: .ssh,
            host: "prod.internal",
            username: "ubuntu",
            lastConnectedAt: now
        )

        #expect(session.lastConnectedAt == now)
    }

    @Test
    func awsProfileAndECSTargetResolutionWorkflow() async throws {
        var app = RemoteOpsApp()
        let profile = AWSProfile(displayName: "prod", accountHint: "123456789012", defaultRegion: "us-east-1", tokenState: .signedIn)

        _ = app.upsertAWSProfile(profile)
        app.selectAWSProfile(id: profile.id)

        let target = try await app.resolveECSTarget(region: "us-east-1")

        #expect(target.awsProfileID == profile.id)
        #expect(target.cluster == "core-cluster")
        #expect(target.task == "task-001")
        #expect(target.container == "app")
        #expect(app.selectedECSExecTarget == target)
    }

    @Test
    func openCodePlaceholderSessionTypeIsSupported() {
        let session = Session(name: "Agent", type: .openCodePlaceholder, host: "placeholder", username: "n/a")
        #expect(session.type == .openCodePlaceholder)
    }
}

extension RemoteOpsCoreTests {
    @Test
    func aiProposalIncludesAssumptions() async throws {
        var app = RemoteOpsApp()
        _ = app.addSession(Session(name: "s", type: .ssh, host: "localhost", username: "me"))

        let proposal = try await app.askAI(intent: "check disk usage")
        #expect(proposal.assumptions.isEmpty == false)
    }

    @Test
    func askAIPrivacyModeRedactsSensitiveTokens() async throws {
        var app = RemoteOpsApp()
        _ = app.addSession(Session(name: "s", type: .ssh, host: "localhost", username: "me"))

        let proposal = try await app.askAI(intent: "check token in logs", privacyMode: .minimalContext)
        #expect(proposal.command == "ls -la")
    }

    @Test
    func sessionConnectionStateMachineTransitions() {
        var machine = SessionConnectionStateMachine()
        #expect(machine.state == .idle)

        machine.startConnection()
        #expect(machine.state == .connecting)

        machine.connectionSucceeded()
        #expect(machine.state == .connected)

        machine.startReconnect()
        #expect(machine.state == .reconnecting)

        machine.authExpired()
        #expect(machine.state == .authExpired)

        machine.connectionFailed("network timeout")
        #expect(machine.state == .failed("network timeout"))
    }

    @Test
    func askAIStateMachineTransitions() {
        var machine = AskAIStateMachine()
        machine.beginPromptEntry()
        #expect(machine.state == .collectingPrompt)

        machine.generate()
        #expect(machine.state == .generating)

        let proposal = AIProposal(command: "df -h", explanation: "disk", risk: .low)
        machine.generated(proposal)
        #expect(machine.state == .generated(proposal))

        machine.awaitApproval(proposal)
        #expect(machine.state == .awaitingApproval(proposal))

        machine.execute(proposal)
        #expect(machine.state == .executing(proposal))

        let commandID = CommandRecord(sessionID: UUID(), command: "df -h", source: .askAI, risk: .low).id
        machine.complete(recordID: commandID)
        #expect(machine.state == .completed(commandID))

        machine.reset()
        #expect(machine.state == .idle)
    }

    @Test
    func historySearchPinTagAndHardDeleteWorkflow() throws {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(Session(name: "prod", type: .ssh, host: "prod.internal", username: "ubuntu"))

        try app.run(command: "sudo systemctl restart api", source: .typed)
        try app.run(command: "df -h", source: .askAI)

        let all = app.searchHistory(scope: .session(sessionID))
        #expect(all.count == 2)

        let restartOnly = app.searchHistory(
            scope: .session(sessionID),
            query: HistoryQuery(text: "restart", source: .typed, risk: .medium)
        )
        #expect(restartOnly.count == 1)

        let recordID = try #require(restartOnly.first?.id)
        app.pinHistoryEntry(id: recordID, pinned: true)
        app.tagHistoryEntry(id: recordID, tags: ["ops", "incident"])

        let tagged = app.searchHistory(
            scope: .global,
            query: HistoryQuery(tag: "ops")
        )
        #expect(tagged.count == 1)
        #expect(tagged[0].pinned == true)

        app.hardDeleteHistoryEntry(id: recordID)
        let remaining = app.searchHistory(scope: .session(sessionID))
        #expect(remaining.count == 1)
    }

    @Test
    func environmentFilteringSupportsLabelTagAndFavorite() {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(Session(name: "infra", type: .ssh, host: "localhost", username: "me"))

        _ = app.addEnvironment(
            EnvironmentProfile(name: "prod", sessionID: sessionID, label: .production, isFavorite: true, tags: ["critical"])
        )
        _ = app.addEnvironment(
            EnvironmentProfile(name: "dev", sessionID: sessionID, label: .development, isFavorite: false, tags: ["sandbox"])
        )

        let prod = app.filteredEnvironments(EnvironmentFilter(label: .production))
        #expect(prod.count == 1)

        let criticalFavorites = app.filteredEnvironments(EnvironmentFilter(tag: "critical", favoritesOnly: true))
        #expect(criticalFavorites.count == 1)
        #expect(criticalFavorites[0].name == "prod")
    }



    @Test
    func ecsSelectionStateMachineTransitions() {
        var machine = ECSSelectionStateMachine()
        #expect(machine.state == .idle)

        machine.startClusterLoad()
        #expect(machine.state == .loadingClusters)

        machine.clustersLoaded(["core-cluster"])
        #expect(machine.state == .selectingCluster(["core-cluster"]))

        machine.startServiceLoad(cluster: "core-cluster")
        #expect(machine.state == .loadingServices(cluster: "core-cluster"))

        machine.servicesLoaded(cluster: "core-cluster", services: ["api"])
        #expect(machine.state == .selectingService(cluster: "core-cluster", services: ["api"]))

        machine.startTaskLoad(cluster: "core-cluster")
        #expect(machine.state == .loadingTasks(cluster: "core-cluster"))

        machine.tasksLoaded(cluster: "core-cluster", tasks: ["task-001"])
        #expect(machine.state == .selectingTask(cluster: "core-cluster", tasks: ["task-001"]))

        machine.startContainerLoad(cluster: "core-cluster", task: "task-001")
        #expect(machine.state == .loadingContainers(cluster: "core-cluster", task: "task-001"))

        machine.containersLoaded(cluster: "core-cluster", task: "task-001", containers: ["app"])
        #expect(machine.state == .selectingContainer(cluster: "core-cluster", task: "task-001", containers: ["app"]))

        let target = ECSExecTarget(
            awsProfileID: UUID(),
            region: "us-east-1",
            cluster: "core-cluster",
            task: "task-001",
            container: "app"
        )
        machine.complete(target: target)
        #expect(machine.state == .ready(target))
    }

    @Test
    func awsAuthStateMachineTransitions() {
        var machine = AWSAuthStateMachine()
        #expect(machine.state == .signedOut)

        machine.startSignIn()
        #expect(machine.state == .signingIn)

        machine.signInSucceeded()
        #expect(machine.state == .signedIn)

        machine.setExpiringSoon()
        #expect(machine.state == .expiringSoon)

        machine.expire()
        #expect(machine.state == .expired)

        machine.fail("callback error")
        #expect(machine.state == .failed("callback error"))

        machine.signOut()
        #expect(machine.state == .signedOut)
    }
    @Test
    func ecsResolutionSelectsServiceWhenNotProvided() async throws {
        var app = RemoteOpsApp()
        let profile = AWSProfile(displayName: "prod", defaultRegion: "us-east-1", tokenState: .signedIn)
        _ = app.upsertAWSProfile(profile)
        app.selectAWSProfile(id: profile.id)

        let target = try await app.resolveECSTarget(region: "us-east-1", preferredCluster: "core-cluster")
        #expect(target.service == "api")
    }

    @Test
    func keysAndConfigsBrowserSupportsMetadataSearch() {
        var app = RemoteOpsApp()
        app.upsertSSHConfig(
            SSHConfigMetadata(alias: "prod-app", hostname: "prod.internal", username: "ubuntu", linkedKeyLabel: "main")
        )
        app.upsertSSHKey(
            SSHKeyMetadata(label: "main", fingerprint: "SHA256:abc", algorithm: "ed25519", source: "import")
        )
        app.upsertGPGKey(
            GPGKeyMetadata(label: "ops-signing", fingerprint: "ABCD1234", capabilities: ["sign", "encrypt"])
        )

        #expect(app.browseSSHConfigs(searchText: "prod").count == 1)
        #expect(app.browseSSHKeys(searchText: "ed25519").count == 1)
        #expect(app.browseGPGKeys(searchText: "encrypt").count == 1)
    }

    @Test
    func createSessionValidatesHostPortAndUsername() throws {
        var app = RemoteOpsApp()

        _ = try app.createSession(name: "infra", type: .ssh, host: "infra.internal", port: 22, username: "ubuntu")
        #expect(app.sessions.count == 1)

        #expect(throws: ValidationError.invalidHost) {
            try app.createSession(name: "bad", type: .ssh, host: "bad host", username: "ubuntu")
        }

        #expect(throws: ValidationError.invalidPort) {
            try app.createSession(name: "bad", type: .ssh, host: "infra.internal", port: 70_000, username: "ubuntu")
        }

        #expect(throws: ValidationError.emptyUsername) {
            try app.createSession(name: "bad", type: .ssh, host: "infra.internal", username: "  ")
        }
    }

    @Test
    func aiModelSelectionFallsBackAndFailsWhenUnavailable() throws {
        let app = RemoteOpsApp()

        let selected = try app.resolveAIModel(
            preferred: "openrouter/gpt-4o-mini",
            availableModels: ["openrouter/gpt-4o-mini", "openrouter/claude-sonnet"],
            defaultModel: "openrouter/claude-sonnet"
        )
        #expect(selected == "openrouter/gpt-4o-mini")

        let fallback = try app.resolveAIModel(
            preferred: "missing/model",
            availableModels: ["openrouter/claude-sonnet"],
            defaultModel: "openrouter/claude-sonnet"
        )
        #expect(fallback == "openrouter/claude-sonnet")

        #expect(throws: ValidationError.unsupportedModel("missing/model")) {
            _ = try app.resolveAIModel(preferred: "missing/model", availableModels: [], defaultModel: "none")
        }
    }

    @Test
    func runAICommandPersistsPromptAndEditState() throws {
        var app = RemoteOpsApp()
        _ = app.addSession(Session(name: "prod", type: .ssh, host: "prod.internal", username: "ubuntu"))

        let proposal = AIProposal(command: "df -h", explanation: "disk", risk: .low)
        try app.runAICommand(prompt: "check disk", proposal: proposal)
        try app.runAICommand(prompt: "check logs", proposal: proposal, editedCommand: "df -h /var")

        let history = app.globalHistory()
        #expect(history.count == 2)
        #expect(history[0].nlPrompt == "check logs")
        #expect(history[0].wasEdited == true)
        #expect(history[1].nlPrompt == "check disk")
        #expect(history[1].wasEdited == false)
    }

    @Test
    func runHistoryCommandCreatesHistorySourceEntry() throws {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(Session(name: "prod", type: .ssh, host: "prod.internal", username: "ubuntu"))

        try app.run(command: "df -h", source: .typed)
        let priorID = try #require(app.searchHistory(scope: .session(sessionID)).first?.id)

        try app.runHistoryCommand(recordID: priorID, editedCommand: "df -h /var")

        let history = app.searchHistory(scope: .session(sessionID))
        #expect(history.count == 2)
        #expect(history[0].source == .history)
        #expect(history[0].command == "df -h /var")
        #expect(history[0].wasEdited == true)
    }

    @Test
    func productionConfirmationRequiredForHighRiskCommands() throws {
        var app = RemoteOpsApp()
        let sessionID = app.addSession(Session(name: "prod", type: .ssh, host: "prod.internal", username: "ubuntu"))
        let envID = app.addEnvironment(EnvironmentProfile(name: "production", sessionID: sessionID, label: .production))
        app.selectEnvironment(id: envID)

        #expect(throws: RemoteOpsError.productionConfirmationMismatch(expected: "production")) {
            try app.validateExecutionApproval(command: "rm -rf /", typedConfirmation: "prod")
        }

        try app.validateExecutionApproval(command: "rm -rf /", typedConfirmation: "production")
        try app.validateExecutionApproval(command: "pwd", typedConfirmation: nil)
    }

    @Test
    func deterministicClockAndIDGeneratorProduceStableHistoryMetadata() throws {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = FixedClock(now: fixedNow)
        let ids = IncrementingIDGenerator(seed: 1)
        var app = RemoteOpsApp(clock: clock, idGenerator: ids)

        let sessionID = try app.createSession(name: "stable", type: .ssh, host: "stable.local", username: "ops")
        app.selectSession(id: sessionID)
        try app.run(command: "ls -la", source: .typed)

        let record = try #require(app.sessionHistory().first)
        #expect(record.timestamp == fixedNow)
        #expect(record.id.uuidString.hasSuffix("000000000002"))
    }

    @Test
    func fullMockModeSeedsDemoData() {
        let app = RemoteOpsApp.fullMock()

        #expect(!app.sessions.isEmpty)
        #expect(!app.environments.isEmpty)
        #expect(!app.globalHistory().isEmpty)
        #expect(!app.awsProfiles.isEmpty)
    }


}
