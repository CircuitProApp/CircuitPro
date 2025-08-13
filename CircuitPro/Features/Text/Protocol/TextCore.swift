import SwiftUI

protocol TextCore {
    var relativePosition: CGPoint { get set }
    var cardinalRotation: CardinalRotation { get set }
    var font: NSFont { get set }
    var color: CGColor { get set }
    var alignment: NSTextAlignment { get set }
    var anchor: TextAnchor { get set }
}
