//
//  ComponentDetailView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/28/25.
//

import SwiftUI

struct ComponentDetailView: View {

    @Environment(\.componentDesignManager)
    private var componentDesignManager

    enum FocusField: Hashable {
        case name
        case referencePrefix
    }

    @FocusState private var focusedField: FocusField?

    
    var body: some View {
        @Bindable var manager = componentDesignManager

        VStack(alignment: .leading, spacing: 25) {
            HStack {
                SectionView("Name") {
                    TextField("e.g. Light Emitting Diode", text: $manager.componentName)
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
                    TextField("e.g. LED", text: $manager.referenceDesignatorPrefix)
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
                    Picker("Category", selection: $manager.selectedCategory) {
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
                SectionView("Package Type") {
                    Picker("Package Type", selection: $manager.selectedPackageType) {
                        Text("Select a Package Type").tag(nil as PackageType?)

                        ForEach(PackageType.allCases) { packageType in
                            Text(packageType.label).tag(Optional(packageType))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 250)
                }
            }
            SectionView("Properties") {
                ComponentPropertiesView(
                    componentProperties: $manager.draftProperties,
                    validationState: componentDesignManager.validationState(for: ComponentDesignStage.ComponentRequirement.properties)
                )
            }
        }
    }
}

