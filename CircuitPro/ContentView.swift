//
//  ContentView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/1/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.openWindow)
    private var openWindow
    var project: CircuitProjectModel
    var body: some View {
        NavigationSplitView {
//            VStack(spacing: 0) {
//                HStack {
//                    Image(systemName: AppIcons.layoutLayers)
//                    Image(systemName: AppIcons.board)
//                    Image(systemName: AppIcons.rectangle)
//                    
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 7)
//                .border(edge: .bottom, style: .quaternary)
//                .border(edge: .top, style: .quaternary)
//                .foregroundStyle(.secondary)
//           
//     
//                List {
//                    Section("Designs") {
//                        HStack {
//                            Text("Design 1")
//                        }
//                        HStack {
//                            Text("Design 2")
//                        }
//                        HStack {
//                            Text("Design 3")
//                        }
//                    }
//           
//                    
//                }
//                .border(edge: .bottom, style: .quaternary)
//                List {
//                    Section("Symbols") {
//                        HStack {
//                            Image(systemName: AppIcons.board)
//                            Text("Switch")
//                                .foregroundStyle(.primary)
//                            Spacer()
//                            Text("S1")
//                                .foregroundStyle(.secondary)
//                        }
//                        HStack {
//                            Text("LED L1")
//                        }
//                        HStack {
//                            Text("Mosfet M1")
//                        }
//                        HStack {
//                            Text("Resistor R1")
//                        }
//                   
//                        HStack {
//                            Text("RPP R1")
//                        }
//                    }
//       
//
//                
//                }
//            }
        } detail: {
            Text("Canvas")
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
