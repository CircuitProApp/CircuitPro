//
//  LibraryManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

@MainActor
@Observable
class LibraryManager {
    
    var remotePackProvider = RemotePackProvider()
    
    var searchText: String = ""
    
    var selectedMode: LibraryMode = .all
    
    var selectedPack: AnyPack?
    
    var selectedComponent: Component?
    
}
