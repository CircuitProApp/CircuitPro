//
//  UTType+CircuitPro.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 06.06.25.
//
import UniformTypeIdentifiers

extension UTType {
    static let circuitProject = UTType(exportedAs: "app.circuitpro.project", conformingTo: .package)
    static let schematic = UTType(exportedAs: "app.circuitpro.schematic")
    static let pcbLayout = UTType(exportedAs: "app.circuitpro.pcb-layout")
}
