//
//  ComponentPropertiesView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/8/25.
//

import SwiftUI

struct ComponentPropertiesView: View {

    @Binding var componentProperties: [DraftProperty]
    var validationState: ValidationState
    
    @State private var selectedProperties: Set<DraftProperty.ID> = []
    @State private var selectedValueType: PropertyValueType = .single

    var body: some View {
        VStack(spacing: 0) {
            Table($componentProperties, selection: $selectedProperties) {
                TableColumn("Key") { $property in
                    PropertyColumn(property: $property, allProperties: componentProperties)
                }
                TableColumn("Value") { $property in
                    ValueColumn(property: $property)
                }
                TableColumn("Unit") { $property in
                    UnitColumn(property: $property)
                }
                TableColumn("Warn on Edit") { $property in
                    WarnOnEditColumn(property: $property)
                }
            }
            .textFieldStyle(.roundedBorder)
            addOrRemoveProperty
        }
        .clipShape(.rect(cornerRadius: 10))
        .validationStatus(validationState)
    }

    var addOrRemoveProperty: some View {
        HStack {
            Button {
                let newProperty = DraftProperty(key: nil, value: .single(nil), unit: .init())
                componentProperties.append(newProperty)
            } label: {
                Image(systemName: CircuitProSymbols.Generic.plus)
            }

            Button {
                componentProperties.removeAll { property in
                    selectedProperties.contains(property.id)
                }
                selectedProperties.removeAll()
            } label: {
                Image(systemName: CircuitProSymbols.Generic.minus)
            }
            .disabled(selectedProperties.isEmpty)

            Spacer()
        }
        .buttonStyle(.bordered)
        .padding(10)
        .background(.thickMaterial)
        .border(edge: .top, style: .stroleColor, thickness: 1)
    }
}

//#Preview {
//    ComponentPropertiesView(
//        componentProperties: .constant(
//            [ComponentProperty(
//                key: .basic(.capacitance),
//                value: .single(10),
//                unit: .init(prefix: .giga, base: .farad),
//                warnsOnEdit: true
//            )]
//        )
//    )
//}
