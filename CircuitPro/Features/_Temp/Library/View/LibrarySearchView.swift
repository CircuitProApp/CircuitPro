//
//  LibrarySearchView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import SwiftDataPacks

struct LibrarySearchView: View {
    
//    @PackManager private var packManager
    
    @Binding var searchText: String
    @State private var isExporterPresented: Bool = false
    @State private var documentToExport: PackDirectoryDocument?
    
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
//            Button {
//                do {
//                    let (doc, _) = try packManager.exportMainStoreAsPack(title: "Base", version: 1)
//                    
//                    self.documentToExport = doc
//                    self.isExporterPresented = true
//                } catch {
//                    print("Export failed: \(error.localizedDescription)")
//                }
//            } label: {
//                Text("E")
//            }

        }
        .padding(13)
        .font(.title2)
//        .fileExporter(
//            isPresented: $isExporterPresented,
//            document: documentToExport,
//            contentType: .folder,
//            defaultFilename: "Base"
//        ) { result in
//            switch result {
//            case .success(let url):
//                print("Saved to \(url)")
//            case .failure(let error):
//                print("Save failed: \(error.localizedDescription)")
//            }
//        }
    }
}
