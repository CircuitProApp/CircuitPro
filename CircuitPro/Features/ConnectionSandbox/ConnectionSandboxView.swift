import SwiftUI

struct ConnectionSandboxView: View {
    private enum SandboxMode: String, CaseIterable, Identifiable {
        case manhattan = "Manhattan"
        case bezier = "Bezier"

        var id: String { rawValue }
    }

    @State private var mode: SandboxMode = .manhattan

    var body: some View {
        Group {
            switch mode {
            case .manhattan:
                WireSandboxView()
            case .bezier:
                BezierSandboxView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Connection Sandbox", selection: $mode) {
                    ForEach(SandboxMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}
