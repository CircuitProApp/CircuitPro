//
//  ListSelectionCore.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftUI

// MARK: - ID plumbing (type-erased container value + ergonomic writer)

private struct ListIDErasedKey: ContainerValueKey {
    static var defaultValue: AnyHashable? { nil }
}

extension ContainerValues {
    var listIDErased: AnyHashable? {
        get { self[ListIDErasedKey.self] }
        set { self[ListIDErasedKey.self] = newValue }
    }
}

extension View {
    /// Attach a strongly-typed row identity used by PlainList/GroupedList selection and range-collection.
    func listID<ID: Hashable>(_ id: ID) -> some View {
        containerValue(\.listIDErased, AnyHashable(id))
    }
}

// MARK: - Ordered IDs collection (for Shift range selection)

struct OrderedIDsKey<ID: Hashable>: PreferenceKey {
    static var defaultValue: [ID] { [] }
    static func reduce(value: inout [ID], nextValue: () -> [ID]) {
        value.append(contentsOf: nextValue())
    }
}

struct OrderedIDsCollector<ID: Hashable>: ViewModifier {
    let isEnabled: Bool
    @Binding var orderedIDs: [ID]

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.onPreferenceChange(OrderedIDsKey<ID>.self) { orderedIDs = $0 }
        } else {
            content
        }
    }
}

// MARK: - Shared selection mode

enum SelectionMode<ID: Hashable> {
    case none
    case single(Binding<ID?>)
    case multi(Binding<Set<ID>>)
}

// MARK: - SelectableRow (shared gestures, anchor, and ordered-ID emission)

struct SelectableRow<ID: Hashable, Row: View>: View {
    let row: Row
    let id: ID
    let mode: SelectionMode<ID>

    @Binding var orderedIDs: [ID]
    @Binding var anchor: ID?

    @Environment(\.listConfiguration) private var configuration

    var body: some View {
        switch mode {
        case .none:
            baseRow(isSelected: false)

        case .single(let single):
            baseRow(isSelected: single.wrappedValue == id)
                .highPriorityGesture(
                    TapGesture()
                        .modifiers(.shift)
                        .onEnded {
                            single.wrappedValue = id
                            anchor = id
                        }
                )
                .gesture(
                    TapGesture()
                        .onEnded {
                            single.wrappedValue = id
                            anchor = id
                        }
                )

        case .multi(let multi):
            baseRow(isSelected: multi.wrappedValue.contains(id))
                .highPriorityGesture(
                    TapGesture()
                        .modifiers(.shift)
                        .onEnded {
                            selectRangeAndReplace(
                                to: id,
                                setSelection: { multi.wrappedValue = $0 }
                            )
                        }
                )
                .highPriorityGesture(
                    TapGesture()
                        .modifiers(.command)
                        .onEnded {
                            var currentSelection = multi.wrappedValue
                            if currentSelection.contains(id) {
                                currentSelection.remove(id)
                            } else {
                                currentSelection.insert(id)
                            }
                            multi.wrappedValue = currentSelection
                            anchor = id
                        }
                )
                .gesture(
                    TapGesture()
                        .onEnded {
                            multi.wrappedValue = [id]
                            anchor = id
                        }
                )
        }
    }

    private func baseRow(isSelected: Bool) -> some View {
        decoratedRow(isSelected: isSelected)
            .preference(key: OrderedIDsKey<ID>.self, value: [id])
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func decoratedRow(isSelected: Bool) -> some View {
        row
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(configuration.listRowPadding)
            .background(isSelected ? configuration.selectionBackgroundColor : .clear)
            .foregroundStyle(isSelected ? configuration.selectionForegroundColor : .primary)
            .clipShape(.rect(cornerRadius: configuration.selectionCornerRadius))
    }

    private func selectRangeAndReplace(
        to id: ID,
        setSelection: (Set<ID>) -> Void
    ) {
        guard let a = anchor,
              let i1 = orderedIDs.firstIndex(of: a),
              let i2 = orderedIDs.firstIndex(of: id) else {
            setSelection([id])
            anchor = id
            return
        }
        let lower = min(i1, i2)
        let upper = max(i1, i2)
        let rangeIDs = orderedIDs[lower...upper]
        let newSelection = Set(rangeIDs)
        setSelection(newSelection)
    }
}
