//
//  ActiveDocumentIDKey.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI

private struct ActiveDocumentIDKey: FocusedValueKey {
    typealias Value = DocumentID
}

extension FocusedValues {
    var activeDocumentID: DocumentID? {
        get { self[ActiveDocumentIDKey.self] }
        set { self[ActiveDocumentIDKey.self] = newValue }
    }
}
