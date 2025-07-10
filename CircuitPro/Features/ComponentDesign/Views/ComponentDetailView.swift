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

    var body: some View {
        @Bindable var manager = componentDesignManager

        VStack(alignment: .leading) {
            HStack {
                SectionView("Name") {
                    TextField("e.g. Light Emitting Diode", text: $manager.componentName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipAndStroke(with: .rect(cornerRadius: 7.5))
                        .validationStatus(componentDesignManager.validationState(for: ComponentDesignStage.ComponentRequirement.name))
                }
                SectionView("Abbreviation") {
                    TextField("e.g. LED", text: $manager.componentAbbreviation)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipAndStroke(with: .rect(cornerRadius: 7.5))
                        .frame(width: 200)
                        .validationStatus(componentDesignManager.validationState(for: ComponentDesignStage.ComponentRequirement.abbreviation))
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
                    .frame(width: 300)
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
                    .frame(width: 300)
                }
            }
            SectionView("Properties") {
                ComponentPropertiesView(
                    componentProperties: $manager.componentProperties,
                    validationState: componentDesignManager.validationState(for: ComponentDesignStage.ComponentRequirement.properties)
                )
            }
        }
    }
}

