//
//  CanvasManager 2.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//
import SwiftUI
import Observation

@Observable
final class ProjectManager {

    var project: Project?
    var selectedDesign: Design?

    var activeComponentInstances: [ComponentInstance] {
        selectedDesign?.componentInstances ?? []
    }
}
