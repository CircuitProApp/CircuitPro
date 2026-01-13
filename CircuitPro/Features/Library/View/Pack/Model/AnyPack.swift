//
//  AnyPack.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftDataPacks
import SwiftUI

enum AnyPack: Identifiable, Hashable {
    case installed(InstalledPack)
    case remote(RemotePack)
    
    var id: UUID {
        switch self {
        case .installed(let installedPack):
            return installedPack.id
        case .remote(let remotePack):
            return remotePack.id
        }
    }
    
    var title: String {
        switch self {
        case .installed(let installedPack):
            return installedPack.metadata.title
        case .remote(let remotePack):
            return remotePack.title
        }
    }
    
    var version: String {
        switch self {
        case .installed(let installedPack):
            return installedPack.metadata.version.description
        case .remote(let remotePack):
            return String(remotePack.version)
        }
    }
    
    var description: String {
        switch self {
        case .installed:
            return "No description"
        case .remote(let remotePack):
            return remotePack.description
        }
    }
}
