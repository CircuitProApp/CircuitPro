enum FeedbackFeatureType: Displayable {
    case connectionCreation
    case navigatorView
    case componentDesign
    case libraryView
    
    var label: String {
        switch self {
        case .connectionCreation: return "Connection Creation"
        case .navigatorView: return "Navigator/Sidebar View"
        case .componentDesign: return "Component Design"
        case .libraryView: return "Library View"
        }
    }
}