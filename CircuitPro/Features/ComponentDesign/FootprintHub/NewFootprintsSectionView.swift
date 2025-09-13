import SwiftUI

struct NewFootprintsSectionView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    @Binding var hubSelectionID: UUID?
    let onOpen: (FootprintDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Footprints")
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            if componentDesignManager.newFootprints.isEmpty {
                Text("No new footprints created.")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16)], spacing: 16) {
                    ForEach(componentDesignManager.newFootprints, id: \.uuid) { footprint in
                        FootprintCardView(footprint: footprint)
                            .onTapGesture {
                                self.onOpen(footprint)
                            }
                    }
                }
            }
        }
    }
}
