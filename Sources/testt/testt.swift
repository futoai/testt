import Foundation
import RemoteOpsCore

@main
struct DemoRemoteOpsApp {
    static func main() async {
        var app = RemoteOpsApp()

        let sessionID = app.addSession(
            Session(
                name: "Prod Web 01",
                type: .ssh,
                host: "prod-web-01.internal",
                username: "ubuntu"
            )
        )

        _ = app.addEnvironment(
            EnvironmentProfile(
                name: "production",
                sessionID: sessionID,
                workingDirectory: "/srv/app",
                shell: "/bin/bash",
                tags: ["critical", "customer-facing"]
            )
        )

        do {
            let proposal = try await app.askAI(intent: "check disk usage")
            print("AI proposal: \(proposal.command) [risk: \(proposal.risk.rawValue)]")
            print("Why: \(proposal.explanation)")

            try app.run(command: proposal.command, source: .askAI, risk: proposal.risk)
            try app.run(command: "journalctl -u app --since '10 min ago'", source: .typed, risk: .low)

            print("\nSession history:")
            for item in app.history.sessionHistory(sessionID: sessionID) {
                print("- \(item.source.rawValue): \(item.command)")
            }
        } catch {
            print("Failed: \(error)")
        }
    }
}
