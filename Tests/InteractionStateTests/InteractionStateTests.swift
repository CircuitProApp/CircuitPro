import XCTest
@testable import CircuitPro

final class InteractionStateTests: XCTestCase {
    func testIdleToStarting() {
        let controller = ConnectionController(repository: NetRepository())
        XCTAssertNil(controller.handle(event: .tap(.zero, CanvasToolContext())))
        XCTAssertEqual(controller.state, .startingRoute)
    }

    func testBackspaceResetsToIdle() {
        let controller = ConnectionController(repository: NetRepository())
        _ = controller.handle(event: .tap(.zero, CanvasToolContext()))
        controller.handle(event: .backspace)
        XCTAssertEqual(controller.state, .idle)
    }
}
