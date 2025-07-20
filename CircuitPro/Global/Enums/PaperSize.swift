import CoreGraphics

enum PaperOrientation { case portrait, landscape }

enum PaperSize {
    enum ISO {
        case a0, a1, a2, a3, a4, a5

        var dimensions: (width: Double, height: Double) {
            switch self {
            case .a0: return (841.0, 1189.0)
            case .a1: return (594.0, 841.0)
            case .a2: return (420.0, 594.0)
            case .a3: return (297.0, 420.0)
            case .a4: return (210.0, 297.0)
            case .a5: return (148.0, 210.0)
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
            }
        }
    }

    enum ANSI {
        case letter, tabloid, c, d, e

        var dimensions: (width: Double, height: Double) {
            switch self {
            case .letter:  return (215.9, 279.4)   //  8.5" × 11"
            case .tabloid: return (279.4, 431.8)   // 11" × 17"
            case .c:       return (431.8, 558.8)   // 17" × 22"
            case .d:       return (558.8, 863.6)   // 22" × 34"
            case .e:       return (863.6, 1117.6)  // 34" × 44"
            }
        }

        var name: String {
            switch self {
            case .letter:  return "Letter"
            case .tabloid: return "Tabloid"
            case .c:       return "ANSI C"
            case .d:       return "ANSI D"
            case .e:       return "ANSI E"
            }
        }
    }

    case iso(ISO)
    case ansi(ANSI)

    var dimensions: (width: Double, height: Double) {
        switch self {
        case .iso(let s):  return s.dimensions
        case .ansi(let s): return s.dimensions
        }
    }

    var aspectRatio: CGFloat {
        let (w, h) = dimensions
        return w / h
    }

    var name: String {
        switch self {
        case .iso(let s):  return s.name
        case .ansi(let s): return s.name
        }
    }

    func canvasSize(
        scale unitsPerMM: CGFloat = 10,
        orientation: PaperOrientation = .landscape
    ) -> CGSize {
        let (wMM, hMM) = dimensions
        let w = CGFloat(wMM) * unitsPerMM
        let h = CGFloat(hMM) * unitsPerMM

        switch orientation {
        case .portrait:  return CGSize(width: w, height: h)
        case .landscape: return CGSize(width: h, height: w)
        }
    }

    static let schematicDefaults: [PaperSize] = [
        .iso(.a3), .iso(.a4), .ansi(.letter)
    ]
    static let layoutDefaults: [PaperSize] = [
        .iso(.a2), .iso(.a3), .ansi(.letter)
    ]
}
