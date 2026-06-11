import Foundation
import LocalForgeCore

@main
struct LocalForgeCLI {
    static func main() async throws {
        var arguments = CommandLine.arguments.dropFirst()
        guard let command = arguments.first else {
            printUsage()
            return
        }
        arguments = arguments.dropFirst()

        switch command {
        case "scan":
            guard let path = arguments.first else {
                print("Missing path")
                printUsage()
                return
            }
            let url = URL(fileURLWithPath: String(path))
            let context = ProjectContext(
                name: url.lastPathComponent,
                rootURL: url,
                permission: .approved(scopeDescription: "CLI explicit path"),
                scanPolicy: .balanced
            )
            let snapshot = try await ScannerEngine().scan(context)
            print("Project: \(snapshot.project.name)")
            print("Type: \(snapshot.identity.kind.rawValue) [\(snapshot.identity.confidence.rawValue)]")
            print("Mission: \(snapshot.mission.statedMission) [\(snapshot.mission.confidence.rawValue)]")
            if snapshot.git.isRepository {
                print("Git: branch \(snapshot.git.branchDisplay), \(snapshot.git.workingTreeSummary)")
            } else {
                print("Git: not a repository")
            }
            print("Reality: \(snapshot.reality.score)% — \(snapshot.reality.currentState)")
            if let risk = snapshot.reality.topRisks.first {
                print("Top risk: \(risk)")
            }
            print("Next action: \(snapshot.reality.nextAction)")
            print("Files: \(snapshot.summary.totalFiles), Source: \(snapshot.summary.sourceFiles), Findings: \(snapshot.findings.count)")
            print("Read-only: \(snapshot.isReadOnly)")

        case "report":
            guard let path = arguments.first else {
                print("Missing path")
                printUsage()
                return
            }
            let url = URL(fileURLWithPath: String(path))
            let context = ProjectContext(
                name: url.lastPathComponent,
                rootURL: url,
                permission: .approved(scopeDescription: "CLI explicit path"),
                scanPolicy: .balanced
            )
            let snapshot = try await ScannerEngine().scan(context)
            print(ReportEngine().markdownReport(for: snapshot))

        case "assess-command":
            let commandText = arguments.joined(separator: " ")
            let assessment = CommandSafetyEngine().assess(commandText)
            print("\(assessment.disposition.rawValue): \(assessment.reason)")

        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }

    private static func printUsage() {
        print(
            """
            LocalForge CLI

            Usage:
              localforge scan <path>
              localforge report <path>
              localforge assess-command <command>

            V1 is read-only and uses the same LocalForgeCore engines as the GUI.
            """
        )
    }
}
