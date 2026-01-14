import CoreGraphics
import Observation

@Observable
final class CanvasRuntimeState {
    var magnification: CGFloat = 1.0
    var mouseLocation: CGPoint?
    var processedMouseLocation: CGPoint?
    var visibleRect: CGRect = .zero
    let hitTargets = HitTargetRegistry()
}

private struct CanvasRuntimeKey: CanvasEnvironmentKey {
    static let defaultValue = CanvasRuntimeState()
}

extension CanvasEnvironmentValues {
    private var runtime: CanvasRuntimeState {
        get { self[CanvasRuntimeKey.self] }
        set { self[CanvasRuntimeKey.self] = newValue }
    }

    var magnification: CGFloat {
        get { runtime.magnification }
        set { runtime.magnification = newValue }
    }

    var mouseLocation: CGPoint? {
        get { runtime.mouseLocation }
        set { runtime.mouseLocation = newValue }
    }

    var visibleRect: CGRect {
        get { runtime.visibleRect }
        set { runtime.visibleRect = newValue }
    }

    var processedMouseLocation: CGPoint? {
        get { runtime.processedMouseLocation }
        set { runtime.processedMouseLocation = newValue }
    }

    var hitTargets: HitTargetRegistry {
        runtime.hitTargets
    }

    var runtimeState: CanvasRuntimeState {
        runtime
    }

    mutating func useRuntime(_ runtime: CanvasRuntimeState) {
        self.runtime = runtime
    }
}
