//
//  SimpleColorPicker.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/4/25.
//

import SwiftUI

struct SimpleColorPicker: View {
    @Binding var selection: Color
    @Binding var isPresented: Bool

    let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .gray,
        .black, .white
    ]

    var body: some View {
        VStack {
            HStack {
                Text("Choose a color")
                    .font(.headline)
                    Spacer()
                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: CircuitProSymbols.Generic.xmark)
                        .symbolVariant(.circle.fill)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 12) {
                ForEach(presetColors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().stroke(Color.primary, lineWidth: color == selection ? 2 : 0)
                                .blur(radius: 5)
                        )
                        .onTapGesture {
                            selection = color
                            isPresented = false
                        }
                }
            }
        }
        .padding(10)
        .frame(width: 200)
    }
}

struct ColorPickerPopoverModifier: ViewModifier {
    @Binding var selection: Color
    @State private var isPresented: Bool = false

    func body(content: Content) -> some View {
        content
            // When the view is tapped, toggle the popover state.
            .onTapGesture {
                isPresented = true
            }
            // Present the popover using the internal isPresented state.
            .popover(isPresented: $isPresented, arrowEdge: .leading) {
                SimpleColorPicker(selection: $selection, isPresented: $isPresented)
            }
    }
}

extension View {
    func colorPickerPopover(selection: Binding<Color>) -> some View {
        self.modifier(ColorPickerPopoverModifier(selection: selection))
    }
}
