//
//  ValueColumn.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/21/25.
//

import SwiftUI

struct ValueColumn: View {
    @Binding var property: PropertyDefinition

    var body: some View {
        HStack {
            if allowedValueType == .single {
                TextField("Value", value: singleBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
            } else {
                HStack {
                    TextField("Min", value: minBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                    Text("-")
                        .foregroundStyle(.secondary)
                    TextField("Max", value: maxBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var allowedValueType: PropertyValueType {
        property.key?.allowedValueType ?? .single
    }

    private var singleBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                if case .single(let val) = property.defaultValue {
                    return val
                } else {
                    return nil
                }
            },
            set: { newVal in
                property.defaultValue = .single(newVal)
            }
        )
    }

    private var minBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                if case .range(let minVal, _) = property.defaultValue {
                    return minVal
                } else {
                    return nil
                }
            },
            set: { newMin in
                if case .range(_, let maxVal) = property.defaultValue {
                    property.defaultValue = .range(min: newMin, max: maxVal)
                }
            }
        )
    }

    private var maxBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                if case .range(_, let maxVal) = property.defaultValue {
                    return maxVal
                } else {
                    return nil
                }
            },
            set: { newMax in
                if case .range(let minVal, _) = property.defaultValue {
                    property.defaultValue = .range(min: minVal, max: newMax)
                }
            }
        )
    }
}
