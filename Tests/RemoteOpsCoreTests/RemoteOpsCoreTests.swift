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
        let sessionID = app.addSession(Session(name: "s", type: .ssh, host: "localhost", username: "me"))

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
}
