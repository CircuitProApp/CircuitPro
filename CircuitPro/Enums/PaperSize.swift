import Foundation

enum PaperSize {
    case a0, a1, a2, a3, a4, a5, a6 // swiftlint:disable:this identifier_name
    case letter, legal

    var dimensions: (width: Double, height: Double) {
        switch self {
        case .a0:     return (841.0, 1189.0)
        case .a1:     return (594.0, 841.0)
        case .a2:     return (420.0, 594.0)
        case .a3:     return (297.0, 420.0)
        case .a4:     return (210.0, 297.0)
        case .a5:     return (148.0, 210.0)
        case .a6:     return (105.0, 148.0)
        case .letter: return (215.9, 279.4)   // 8.5 × 11 inches
        case .legal:  return (215.9, 355.6)   // 8.5 × 14 inches
        }
    }

    var name: String {
        switch self {
        case .a0: return "A0"
        case .a1: return "A1"
        case .a2: return "A2"
        case .a3: return "A3"
        case .a4: return "A4"
        case .a5: return "A5"
        case .a6: return "A6"
        case .letter: return "Letter"
        case .legal: return "Legal"
        }
    }
}
