import SwiftUI
import SwiftData

@Model
final class Schematic {

    var title: String
    var timestamps: Timestamps
    var design: Design?

    @Relationship(deleteRule: .cascade, inverse: \Net.schematic)
    var nets: [Net] = []

    init(title: String, design: Design? = nil) {
        self.title = title
        self.design = design
        self.timestamps = Timestamps()
    }
}
