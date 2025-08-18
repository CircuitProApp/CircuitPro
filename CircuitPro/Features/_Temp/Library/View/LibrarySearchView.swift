//
//  LibrarySearchView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import AppKit
import SwiftDataPacks

struct LibrarySearchView: View {
    
    @PackManager private var packManager
    
    @Binding var searchText: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(.secondary)
            
            TextField("Search Components", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onAppear { isFocused = true }
            Spacer(minLength: 0)
            
            if searchText.isNotEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: CircuitProSymbols.Generic.xmark)
                        .symbolVariant(.circle.fill)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            Button("E") {
                exportWithSavePanel()
            }
            Button("I") {
                importPack()
            }
        }
        .padding(13)
        .font(.title2)
    }
    
    private func importPack() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Pack"
        openPanel.canChooseDirectories = true
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            packManager.installPack(from: url)
        }
    }
    
    private func exportWithSavePanel() {
        do {
            let (doc, _) = try packManager.exportMainStoreAsPack(title: "Base", version: 1)

            let savePanel = NSSavePanel()
            savePanel.title = "Export Pack"
            savePanel.nameFieldStringValue = "Base"
            savePanel.canCreateDirectories = true
            savePanel.allowedContentTypes = [.folder]

            if savePanel.runModal() == .OK, let url = savePanel.url {
                do {
                    let wrapper = try doc.asFileWrapper()
                    try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
                    print("Saved to \(url)")
                } catch {
                    print("Save failed: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }
}
