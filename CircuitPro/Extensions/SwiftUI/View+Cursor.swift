//
//  View+Cursor.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 25.05.25.
//

import SwiftUI

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover {
            if $0 {
                cursor.push()
            } else {
                cursor.pop()
            }
        }
    }
}
