import SwiftUI
import AppKit

struct EditorView: View {
    @State private var showUtilityArea: Bool = true
    
    @State private var selectedEditor: EditorType = .schematic
    
    @State private var schematicCanvasManager = CanvasManager()
    @State private var layoutCanvasManager = CanvasManager()
    
    var selectedCanvasManager: CanvasManager {
        switch selectedEditor {
        case .schematic:
            return schematicCanvasManager
        case .layout:
            return layoutCanvasManager
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    selectedEditor = .schematic
                } label: {
                    Text("Schematic")
                        .directionalPadding(vertical: 3, horizontal: 7.5)
                        .background(selectedEditor == .schematic ? AnyShapeStyle(Color.blue.quaternary) : AnyShapeStyle(Color.clear))
                        .foregroundStyle(selectedEditor == .schematic ? .primary : .secondary)
                        .clipShape(.rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button {
                    selectedEditor = .layout
                } label: {
                    Text("Layout")
                        .directionalPadding(vertical: 3, horizontal: 7.5)
                        .background(selectedEditor == .layout ? AnyShapeStyle(Color.blue.quaternary) : AnyShapeStyle(Color.clear))
                        .foregroundStyle(selectedEditor == .layout ? .primary : .secondary)
                        .clipShape(.rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
          
                Spacer()
            }
            .frame(height: 27.25)
            .frame(maxWidth: .infinity)
            .font(.system(size: 11))
        
            
            Divider()
                .foregroundStyle(.quaternary)
            
            SplitView(showBottomView: $showUtilityArea) {
                switch selectedEditor {
                   case .schematic:
                    SchematicView(canvasManager: selectedCanvasManager)
                case .layout:
                    LayoutView()
                }
            } dividerView: {
                StatusBarView(canvasManager: selectedCanvasManager, showUtilityArea: $showUtilityArea)
         
            } bottomView: {
                UtilityAreaView()
            }
            
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(selectedCanvasManager)
    }
}

#Preview {
    EditorView()
}

