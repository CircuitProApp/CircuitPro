import SwiftUI
import SwiftData

@Model
final class Design {

    var name: String
    var timestamps: Timestamps

    @Relationship(deleteRule: .cascade, inverse: \Schematic.design)
    var schematic: Schematic?

    @Relationship(deleteRule: .cascade, inverse: \Layout.design)
    var layout: Layout?

//    @Relationship(deleteRule: .cascade, inverse: \ComponentInstance.design)
//    var componentInstances: [ComponentInstance]

    var project: Project

    init(
        name: String,
        schematic: Schematic? = nil,
        layout: Layout? = nil,
        project: Project,
//        componentInstances: [ComponentInstance] = []
    ) {
        self.name = name
        self.schematic = schematic
        self.layout = layout
        self.project = project
//        self.componentInstances = componentInstances
        self.timestamps = Timestamps()
    }
}
