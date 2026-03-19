//
//  FootprintNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import AppKit
import SwiftUI

private struct LayoutNavigatorDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.smooth(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    configuration.label
                    Spacer()
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(.quaternary.opacity(0.45))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 0)
            }
        }
    }
}

struct FootprintNavigatorView: View {
    private enum PlacementBucket: Hashable {
        case unplaced
        case front
        case back
    }

    @BindableEnvironment(\.projectManager) private var projectManager
    @BindableEnvironment(\.editorSession) private var editorSession
    @State private var expandedBuckets: Set<PlacementBucket> = [.unplaced, .front, .back]

    private var unplacedComponents: [ComponentInstance] {
        projectManager.componentInstances.filter {
            $0.footprintInstance?.placement == .unplaced
        }
    }

    private func placedComponents(on side: BoardSide) -> [ComponentInstance] {
        projectManager.componentInstances.filter { component in
            guard let footprint = component.footprintInstance else { return false }
            if case .placed(let footprintSide) = footprint.placement {
                return footprintSide == side
            }
            return false
        }
    }

    /// Handles deletion of component instances based on selection.
    // This function is identical to the one in SymbolNavigatorView.
    private func performDelete(on componentInstance: ComponentInstance, selected: inout Set<UUID>) {
        let idsToRemove: Set<UUID>

        let isMultiSelect = selected.contains(componentInstance.id) && selected.count > 1

        if isMultiSelect {
            idsToRemove = selected
        } else {
            idsToRemove = [componentInstance.id]
        }

        projectManager.selectedDesign.componentInstances.removeAll { idsToRemove.contains($0.id) }
        selected.subtract(idsToRemove)  // Clear selection for deleted items
        projectManager.document.scheduleAutosave()
    }

    private func rowBackgroundColor(isSelected: Bool) -> Color {
        isSelected
            ? Color(nsColor: .selectedContentBackgroundColor)
            : .clear
    }

    private func rowStrokeColor(isSelected: Bool) -> Color {
        isSelected
            ? Color(nsColor: .selectedControlColor).opacity(0.35)
            : .clear
    }

    private func primaryTextColor(isSelected: Bool) -> Color {
        isSelected
            ? Color(nsColor: .alternateSelectedControlTextColor)
            : .primary
    }

    private func secondaryTextColor(isSelected: Bool) -> Color {
        isSelected
            ? Color(nsColor: .alternateSelectedControlTextColor).opacity(0.8)
            : .secondary
    }

    private func selectComponent(_ componentID: UUID) {
        if NSEvent.modifierFlags.contains(.command) {
            if editorSession.selectedItemIDs.contains(componentID) {
                editorSession.selectedItemIDs.remove(componentID)
            } else {
                editorSession.selectedItemIDs.insert(componentID)
            }
        } else {
            editorSession.selectedItemIDs = [componentID]
        }
    }

    var body: some View {
        VStack(spacing: 0) {  // Added VStack for similar structure to SymbolNavigatorView
            if projectManager.componentInstances.isEmpty {  // Checking all component instances
                SidebarContentUnavailableView("No Footprints")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        disclosureGroup(
                            title: "Unplaced",
                            bucket: .unplaced,
                            components: unplacedComponents,
                            emptyMessage: "All components placed.",
                            allowsDrag: true
                        )

                        disclosureGroup(
                            title: "Placed on Front",
                            bucket: .front,
                            components: placedComponents(on: .front),
                            emptyMessage: "No components on front."
                        )

                        disclosureGroup(
                            title: "Placed on Back",
                            bucket: .back,
                            components: placedComponents(on: .back),
                            emptyMessage: "No components on back."
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder
    private func disclosureGroup(
        title: String,
        bucket: PlacementBucket,
        components: [ComponentInstance],
        emptyMessage: String,
        allowsDrag: Bool = false
    ) -> some View {
        DisclosureGroup(isExpanded: binding(for: bucket)) {
            if components.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(components) { component in
                        componentRow(for: component, allowsDrag: allowsDrag)
                    }
                }
            }
        } label: {
            Text(title)
                .fontWeight(.semibold)
        }
        .disclosureGroupStyle(LayoutNavigatorDisclosureGroupStyle())
    }

    @ViewBuilder
    private func componentRow(for component: ComponentInstance, allowsDrag: Bool = false)
        -> some View
    {
        let isSelected = editorSession.selectedItemIDs.contains(component.id)

        let row = HStack {
            Text(component.referenceDesignator)
                .foregroundStyle(primaryTextColor(isSelected: isSelected))
            Spacer()
            Text(component.footprintInstance?.definition?.name ?? "Default")
                .foregroundStyle(secondaryTextColor(isSelected: isSelected))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackgroundColor(isSelected: isSelected))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowStrokeColor(isSelected: isSelected), lineWidth: 1)
        }
        .frame(minHeight: 22)
        .contentShape(Rectangle())
        .onTapGesture {
            selectComponent(component.id)
        }
        .contextMenu {
            contextMenu(for: component)
        }

        if allowsDrag {
            row.draggable(TransferablePlacement(componentInstanceID: component.id))
        } else {
            row
        }
    }

    @ViewBuilder
    private func contextMenu(for component: ComponentInstance) -> some View {
        let multi =
            editorSession.selectedItemIDs.contains(component.id)
            && editorSession.selectedItemIDs.count > 1

        Button(role: .destructive) {
            performDelete(on: component, selected: &editorSession.selectedItemIDs)
        } label: {
            Text(
                multi
                    ? "Delete Selected (\(editorSession.selectedItemIDs.count))"
                    : "Delete")
        }
    }

    private func binding(for bucket: PlacementBucket) -> Binding<Bool> {
        Binding(
            get: { expandedBuckets.contains(bucket) },
            set: { isExpanded in
                if isExpanded {
                    expandedBuckets.insert(bucket)
                } else {
                    expandedBuckets.remove(bucket)
                }
            }
        )
    }
}
