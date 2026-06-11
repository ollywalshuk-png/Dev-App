import LocalForgeCore
import SwiftUI

struct EngineFoundationView: View {
    var module: WorkspaceModule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(module.rawValue) Foundation")
                .font(.title3.weight(.semibold))
            Text("V1 exposes this module honestly as a foundation surface. Implemented engines and explicit stubs are listed below.")
                .foregroundStyle(.secondary)

            ForEach(EngineRegistry.v1Foundations) { engine in
                HStack(alignment: .firstTextBaseline) {
                    Text(engine.name)
                        .font(.headline)
                    Spacer()
                    Text(engine.status)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
