//
//  PropertyColumn.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/21/25.
//

import SwiftUI

struct PropertyColumn: View {
    @Binding var property: DraftProperty
    let allProperties: [DraftProperty]

    var body: some View {
        Menu {
            // Basic Types
            ForEach(PropertyKey.BasicType.allCases, id: \.self) { type in
                Button {
                    setKey(.basic(type))
                } label: {
                    Text(type.label)
                }
                .disabled(isDisabled(for: .basic(type)))
            }
            Divider()

            // Rating Types
            Menu("Rating") {
                ForEach(PropertyKey.RatingType.allCases, id: \.self) { type in
                    Button {
                        setKey(.rating(type))
                    } label: {
                        Text(type.label)
                    }
                    .disabled(isDisabled(for: .rating(type)))
                }
            }

            // Temperature Types
            Menu("Temperature") {
                ForEach(PropertyKey.TemperatureType.allCases, id: \.self) { type in
                    Button {
                        setKey(.temperature(type))
                    } label: {
                        Text(type.label)
                    }
                    .disabled(isDisabled(for: .temperature(type)))
                }
            }

            // RF Types
            Menu("RF") {
                ForEach(PropertyKey.RFType.allCases, id: \.self) { type in
                    Button {
                        setKey(.rf(type))
                    } label: {
                        Text(type.label)
                    }
                    .disabled(isDisabled(for: .rf(type)))
                }
            }

            // Battery Types
            Menu("Battery") {
                ForEach(PropertyKey.BatteryType.allCases, id: \.self) { type in
                    Button {
                        setKey(.battery(type))
                    } label: {
                        Text(type.label)
                    }
                    .disabled(isDisabled(for: .battery(type)))
                }
            }

            // Sensor Types
            Menu("Sensor") {
                ForEach(PropertyKey.SensorType.allCases, id: \.self) { type in
                    Button {
                        setKey(.sensor(type))
                    } label: {
                        Text(type.label)
                    }
                    .disabled(isDisabled(for: .sensor(type)))
                }
            }
        } label: {
            Text(property.key?.label ?? "Select a Property")
        }
    }

    // Disable if this property is already selected elsewhere
    private func isDisabled(for key: PropertyKey) -> Bool {
        allProperties.contains { $0.key == key && $0.id != property.id }
    }

    private func setKey(_ key: PropertyKey) {
        property.key = key

        // Correct the property's value type
        switch key.allowedValueType {
        case .single:
            if case .range = property.value {
                property.value = .single(nil)
            }
        case .range:
            if case .single = property.value {
                property.value = .range(min: nil, max: nil)
            }
        }

        // Set default unit if there's exactly 1 allowed unit
        if let firstAllowed = key.allowedBaseUnits.first, key.allowedBaseUnits.count == 1 {
            property.unit.base = firstAllowed
            property.unit.prefix = nil // Reset prefix
        } else {
            property.unit.base = nil
            property.unit.prefix = nil // Reset prefix
        }
    }

}
