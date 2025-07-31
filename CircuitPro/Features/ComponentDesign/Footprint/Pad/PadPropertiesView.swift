//
//  PadPropertiesView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct PadPropertiesView: View {
    
    @State private var showDrillDialog: Bool = false
    
    @Binding var pad: Pad
    
    var isTooLarge: Bool {
        guard pad.type == .throughHole else { return false }

        guard let drill = pad.drillDiameter, drill > 0 else { return false }

        return pad.isCircle
        ? drill > pad.radius
        : drill > pad.width || drill > pad.height
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            InspectorSection("Identity and Type") {
                InspectorRow("Number") {
                    HStack(spacing: 4) {
                        InspectorNumericField(value: $pad.number)
                        Color.clear
                    }
                }
                InspectorRow("Pad Type") {
                    Picker("Pad Type", selection: $pad.type) {
                        ForEach(PadType.allCases) { padType in
                            Text(padType.label).tag(padType)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                
                InspectorRow("Drill Diameter") {
                    HStack(spacing: 4) {
               
                        
                        InspectorNumericField(
                            value: Binding(
                                get: { pad.drillDiameter ?? 0.0 },
                                set: { pad.drillDiameter = $0 }
                            ),
                            displayMultiplier: 0.1,
                            suffix: "mm"
                        )
                        .environment(\.focusRingColor, isTooLarge ? .red : .clear)
                        .disabled(pad.type != .throughHole)
                        
                        if isTooLarge {
                            ZStack {
                                Image(systemName: CircuitProSymbols.Workspace.ruleChecks)
                                    .symbolVariant(.fill)
                                    .foregroundStyle(.primary, .yellow)
                                
                                    .onHover { _ in showDrillDialog.toggle() }
                                    .popover(isPresented: $showDrillDialog) {
                                        Text("Drill diameter exceeds pad size.")
                                            .padding(7.5)
                                    }
                                    .transition(.blurReplace)
                               
                            }
                      
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Color.clear
                        }
                      
                        
                    }
                    .animation(.default, value: isTooLarge)
                }
                
            }
            Divider()
            InspectorSection("Transform") {
                PointControlView(title: "Position", point: $pad.position, displayOffset: PaperSize.component.centerOffset())
      
                RotationControlView(object: $pad, tickStepDegrees: 90)
            }
            Divider()
            InspectorSection("Display") {
                InspectorRow("Shape") {
                    Picker("Shape", selection: Binding(
                        get: { pad.isCircle ? "Circle" : "Rectangle" },
                        set: { pad.shape = $0 == "Circle" ? .circle(radius: 5) : .rect(width: 5, height: 10) }
                    )) {
                        Text("Circle").tag("Circle")
                        Text("Rectangle").tag("Rectangle")
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                if pad.isCircle {
                    InspectorRow("Radius") {
                        HStack(spacing: 4) {
                            InspectorNumericField(value: $pad.radius, displayMultiplier: 0.1, suffix: "mm")
                                .environment(\.focusRingColor, isTooLarge ? .red : .clear)
                        }
                    }
                    
                    
                    
                    
                } else {
                    InspectorRow("Dimensions") {
                        HStack(spacing: 4) {
                            InspectorNumericField(title: "W", value: $pad.width, displayMultiplier: 0.1, suffix: "mm")
                            
                            
                            InspectorNumericField(title: "H", value: $pad.height, displayMultiplier: 0.1, suffix: "mm")
                        }
                        .environment(\.focusRingColor, isTooLarge ? .red : .clear)
                    }
                    
                    
                }
            }

            
            
        }
        .padding(10)
    }
}
