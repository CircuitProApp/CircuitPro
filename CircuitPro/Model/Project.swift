import Foundation
import SwiftData

@Model
final class Project {

    var name: String
    var timestamps: Timestamps

    @Relationship(deleteRule: .cascade, inverse: \Design.project)
    var designs: [Design]

    init(name: String, designs: [Design]) {
        self.name = name
        self.timestamps = Timestamps()
        self.designs = designs
    }
}
