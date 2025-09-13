import SwiftUI

struct FootprintCardView: View {
    
    let footprint: FootprintDefinition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .aspectRatio(1, contentMode: .fit)
                
                Image(systemName: "square.grid.3x3.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            .clipShape(.rect(cornerRadius: 12))
            
            Text(footprint.name)
                .font(.headline)
                .padding(.horizontal, 4)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }
}
