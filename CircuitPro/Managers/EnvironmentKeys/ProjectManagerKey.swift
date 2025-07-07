//
//  CanvasManagerKey 2.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/8/25.
//

import SwiftUI

@MainActor
private struct ProjectManagerKey: @preconcurrency EnvironmentKey {
    static let defaultValue: ProjectManager = ProjectManager(project: .init(name: "Untitled", designs: []), modelContext: ModelContainerManager.shared.container.mainContext)
}

extension EnvironmentValues {
    var projectManager: ProjectManager {
        get { self[ProjectManagerKey.self] }
        set { self[ProjectManagerKey.self] = newValue }
    }
}
