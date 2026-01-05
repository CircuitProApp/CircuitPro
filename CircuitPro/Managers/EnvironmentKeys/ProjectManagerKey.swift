//
//  CanvasManagerKey 2.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/8/25.
//

import SwiftUI

private struct ProjectManagerKey: EnvironmentKey {
    @MainActor
    static var defaultValue: ProjectManager {
        ProjectManager(
            document: .init(newWithName: "")
        )
    }
}

extension EnvironmentValues {
    @MainActor
    var projectManager: ProjectManager {
        get { self[ProjectManagerKey.self] }
        set { self[ProjectManagerKey.self] = newValue }
    }
}
