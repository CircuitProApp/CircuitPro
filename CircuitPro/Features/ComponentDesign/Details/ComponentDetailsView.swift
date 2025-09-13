//
//  ComponentDetailsView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/28/25.
//

import SwiftUI

enum ComponentDetailsFocusField: Hashable {
    case name
    case referencePrefix
}

struct ComponentDetailsView: View {

    @BindableEnvironment(ComponentDesignManager.self)
    private var componentDesignManager

    @FocusState.Binding var focusedField: ComponentDetailsFocusField?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack {
                SectionView("Name") {
                    TextField("e.g. Light Emitting Diode", text: $componentDesignManager.componentName)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .name)
                     
                        .font(.title3)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipAndStroke(with: .rect(cornerRadius: 7.5))
                        .focusRing(focusedField == .name, shape: .rect(cornerRadius: 8.5))
                        .environment(\.focusRingColor, componentDesignManager.validationState(for: ComponentDesignStage.ComponentRequirement.name).contains(.error) ? .red : .clear)
                }
                SectionView("Reference Designator Prefix") {
                    TextField("e.g. LED", text: $componentDesignManager.referenceDesignatorPrefix)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .referencePrefix)
                        .font(.title3)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipAndStroke(with: .rect(cornerRadius: 7.5))
                        .frame(width: 250)
                        .focusRing(focusedField == .referencePrefix, shape: .rect(cornerRadius: 8.5))
                        .environment(\.focusRingColor, componentDesignManager.validationState(for: ComponentDesignStage.ComponentRequirement.referenceDesignatorPrefix).contains(.error) ? .red : .clear)
                }
            }

            HStack {
                SectionView("Category") {
                    Picker("Category", selection: $componentDesignManager.selectedCategory) {
                        Text("Select a Category").tag(nil as ComponentCategory?)

                        ForEach(ComponentCategory.allCases) { category in
                            Text(category.label).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 250)
                    .validationStatus(componentDesignManager.validationState(for: ComponentDesignStage.ComponentRequirement.category))
                }
//                SectionView("Package Type") {
//                    Picker("Package Type", selection: $manager.selectedPackageType) {
//                        Text("Select a Package Type").tag(nil as PackageType?)
//
//                        ForEach(PackageType.allCases) { packageType in
//                            Text(packageType.label).tag(Optional(packageType))
//                        }
//                    }
//                    .pickerStyle(.menu)
//                    .labelsHidden()
//                    .frame(width: 250)
//                }
            }
            SectionView("Properties") {
                ComponentPropertiesView(
                    componentProperties: $componentDesignManager.draftProperties,
                    validationState: componentDesignManager.validationState(for: ComponentDesignStage.ComponentRequirement.properties)
                )
            }
        }
    }
}

