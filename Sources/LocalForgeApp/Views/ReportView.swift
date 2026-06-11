import SwiftUI

struct ReportView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Copyable Project Report")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.reportForSelectedProject(), forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            TextEditor(text: .constant(store.reportForSelectedProject()))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 420)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
