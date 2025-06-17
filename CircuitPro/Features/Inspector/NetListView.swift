//
//  NetListView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/4/25.
//

import SwiftUI

struct NetListView: View {

//    let nets: [Net]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Nets")
                .font(.headline)
                .padding(.horizontal)

//            List(nets) { net in
//                HStack(alignment: .firstTextBaseline) {
//
//                    Image(systemName: "circle.fill")
//                        .foregroundStyle(net.color.color)
//                        .colorPickerPopover(selection: net.colorBinding)
//
//                    Button {
//                        net.isHidden.toggle()
//                    } label: {
//                        Image(systemName: net.isHidden ? AppIcons.eyeSlash : AppIcons.eye)
//                            .foregroundStyle(net.isHidden ? .secondary : .primary)
//                    }
//                    .contentTransition(.symbolEffect(.replace))
//                    .buttonStyle(.plain)
//
//                    Text(net.name)
//                        .padding(.bottom, 8)
//                        .padding(.top, 4)
//                        .font(.callout)
//                }
//            }
        }
    }
}

//#Preview {
//    NetListView(nets: [])
//}
