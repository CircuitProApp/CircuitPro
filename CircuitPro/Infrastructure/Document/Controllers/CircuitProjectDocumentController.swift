import Cocoa
import UniformTypeIdentifiers
import WelcomeWindow

final class CircuitProjectDocumentController: NSDocumentController {

    override func documentClass(forType typeName: String) -> AnyClass? {
        print("📂 Resolving class for type:", typeName)
        return CircuitProjectDocument.self
    }
}
