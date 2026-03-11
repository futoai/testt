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

        try app.run(command: "ls -la", source: .typed, risk: .low)

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
}
