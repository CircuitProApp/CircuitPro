import AppKit

struct CKText: CKShape {
    let content: String
    let font: NSFont
    var style: CKStyle = .init()

    init(_ content: String, font: NSFont) {
        self.content = content
        self.font = font
        self.style.fillColor = NSColor.labelColor.cgColor
    }

    func shapePath() -> CGPath {
        let textPath = TextUtilities.path(for: content, font: font)
        guard !textPath.isEmpty else { return CGMutablePath() }
        let bounds = textPath.boundingBoxOfPath
        let position = style.position ?? .zero
        let transform = CGAffineTransform(
            translationX: position.x - bounds.midX,
            y: position.y - bounds.midY
        )
        let finalPath = CGMutablePath()
        finalPath.addPath(textPath, transform: transform)
        return finalPath
    }
}
