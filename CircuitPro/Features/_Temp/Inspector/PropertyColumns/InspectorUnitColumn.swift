//
//  InspectorUnitColumn.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/27/25.
//

import SwiftUI

struct InspectorUnitColumn: View {
    
    @Binding var property: Property.Resolved
    
    var body: some View {
        HStack(spacing: 2.5) {
            Menu {
                Button("None") {
                    property.unit.prefix = nil
                }
                Divider()
                ForEach(SIPrefix.allCases, id: \.rawValue) { prefix in
                    Button {
                        property.unit.prefix = prefix
                    } label: {
                        Text(prefix.name)
                    }
                }
            } label: {
                Text(property.unit.prefix?.symbol ?? "–")
            }
            .disabled(!(property.unit.base?.allowsPrefix ?? false)) // Disable prefix menu if not allowed
            .controlSize(.small)

            if allowedBaseUnits.count == 1, let base = allowedBaseUnits.first {
                Text(base.symbol)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(2.5)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 2.5))
            } else {
                Menu {
                    ForEach(allowedBaseUnits, id: \.rawValue) { base in
                        Button {
                            property.unit.base = base
                            if !base.allowsPrefix {
                                property.unit.prefix = nil
                            }
                        } label: {
                            Text(base.name)
                        }
                    }
                } label: {
                    Text(property.unit.base?.symbol ?? "–")
                        .foregroundStyle(property.unit.base == nil ? .secondary : .primary)
                }
            }

        }
    }

    private var allowedBaseUnits: [BaseUnit] {
        property.key.allowedBaseUnits
    }
}
