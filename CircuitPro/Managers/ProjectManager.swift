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

    var project: CircuitProject
    var selectedDesign: CircuitDesign?
    
    var selectedDesignComponents: [ComponentInstance] {
        selectedDesign?.componentInstances ?? []
    }

    init(project: CircuitProject, selectedDesign: CircuitDesign? = nil) {
        self.project = project
        self.selectedDesign = selectedDesign
    }
}
