# Canvas Rendering Idea Draft

This is a quick, non-binding sketch of a CanvasKit rendering DSL. It is not a plan,
just a place to capture the current ideation so we can revisit it later.

## Goal
- Provide SwiftUI-style ergonomics for CanvasKit render layers without tying
  rendering logic directly to model types.
- Keep renderers composable and type-safe, while returning `DrawingPrimitive`s.

## Sketch Concepts
- **CanvasRenderer**: composable unit that can render into primitives.
- **ItemRenderer**: maps a concrete `CanvasItem` type into a `CanvasRenderer`.
- **Result Builder**: allows `switch`/`if`/`for` inside renderer bodies, similar to SwiftUI.

## Example-ish Usage (Conceptual)
```swift
struct PinRenderer: ItemRenderer {
    func body(for pin: Pin, context: RenderContext) -> some CanvasRenderer {
        Draw {
            // build primitives for pin geometry + text
        }
    }
}

struct ElementRenderer: CanvasRenderer {
    var body: some CanvasRenderer {
        ForEach(items) { item in
            switch item {
            case is Pin: PinRenderer()
            case is Symbol: SymbolRenderer()
            }
        }
    }
}
```

## Notes
- This is meant to feel declarative but still return low-level primitives.
- The API should stay lightweight; no views or heavyweight layout.
- This can live entirely in CanvasKit without leaking into app models.
