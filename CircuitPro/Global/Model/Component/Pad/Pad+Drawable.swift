import AppKit

extension Pad: Drawable {

    // MARK: - Private Path Generation Helper
    
    /// A helper that generates the final, geometrically correct path for the pad's body.
    private func getFinalPath() -> CGPath {
        let shapePath = CGMutablePath()
        shapePrimitives.forEach { shapePath.addPath($0.makePath()) }
        
        guard type == .throughHole else { return shapePath }
        
        let drillPath = CGMutablePath()
        maskPrimitives.forEach { drillPath.addPath($0.makePath()) }
        
        return shapePath.subtracting(drillPath)
    }

    // MARK: - Drawable Protocol Conformance

    func makeBodyParameters() -> [DrawingParameters] {
        let path = getFinalPath()
        guard !path.isEmpty else { return [] }
        
        let copperColor = shapePrimitives.first?.color.cgColor ?? NSColor.systemBlue.cgColor
        
        return [DrawingParameters(
            path: path,
            lineWidth: 0,
            fillColor: copperColor,
            strokeColor: nil
        )]
    }

    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
        // A pad only shows a halo if it is directly selected.
        guard selectedIDs.contains(self.id) else { return nil }

        let haloWidth: CGFloat = 4.0
        let haloColor = shapePrimitives.first?.color.cgColor.copy(alpha: 0.3) ?? NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        
        let shapePath = CGMutablePath()
        shapePrimitives.forEach { shapePath.addPath($0.makePath()) }
        guard !shapePath.isEmpty else { return nil }
        
        let thickOutline = shapePath.copy(strokingWithWidth: haloWidth * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        let enlargedShape: CGPath = thickOutline.union(shapePath)

        let finalHaloPath: CGPath
        if type == .throughHole {
            let drillPath = CGMutablePath()
            maskPrimitives.forEach { drillPath.addPath($0.makePath()) }
            finalHaloPath = enlargedShape.subtracting(drillPath)
        } else {
            finalHaloPath = enlargedShape
        }
        
        guard !finalHaloPath.isEmpty else { return nil }
        
        return DrawingParameters(
            path: finalHaloPath,
            lineWidth: 0,
            fillColor: haloColor,
            strokeColor: nil
        )
    }
}
