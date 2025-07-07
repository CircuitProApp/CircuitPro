////
////  LayerListView.swift
////  Circuit Pro
////
////  Created by Giorgi Tchelidze on 4/4/25.
////
//
// import SwiftUI
// import SwiftData
//
// struct LayerListView: View {
//
//    let layers: [Layer]
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text("Layers")
//                .font(.headline)
//                .padding(.horizontal)
//
//            List(layers) { layer in
//                HStack(alignment: .firstTextBaseline) {
//                    Image(systemName: "circle.fill")
//                        .foregroundStyle(layer.color.color)
//                        .colorPickerPopover(selection: layer.colorBinding)
//
//                    Button {
//                        layer.isHidden.toggle()
//                        print(layer.isHidden)
//                    } label: {
//                        Image(systemName: layer.isHidden ? AppIcons.eyeSlash : AppIcons.eye)
//                            .foregroundStyle(layer.isHidden ? .secondary : .primary)
//                    }
//                    .contentTransition(.symbolEffect(.replace))
//                    .buttonStyle(.plain)
//
//                    Text(layer.type.rawValue)
//                        .padding(.bottom, 8)
//                        .padding(.top, 4)
//                        .font(.callout)
//                }
//            }
//        }
//    }
// }
