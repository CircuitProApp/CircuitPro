# CanvasKit Architecture (Target)

## Goals
- Keep core models domain-only (symbols, pins, pads, primitives).
- Use CanvasKit as a view-layer adapter, not a persistence layer.
- Ensure a single, predictable render/hit/interaction path.

## Core Concepts
- **Model types**: `Symbol`, `Pin`, `Rectangle`, `Pad`, etc. Pure data. No CanvasKit protocols.
- **Canvas items (adapters)**: `CanvasSymbol`, `CanvasRectangle`, `CanvasPin`, `CanvasFootprint`, etc.
- **Canvas graph**: `CanvasGraph` holds only canvas items that are interactive/selectable.
- **Environment**: theme, grid, overlays only (no scene objects).

## Graph Elements & Selection
- `CanvasGraph` stores **nodes** (`NodeID`) and **edges** (`EdgeID`) separately.
- `GraphElementID` unifies selection across nodes and edges.
- Wires/traces live as edge components and participate in the same render/hit/halo path.

## Capability Protocols (Canvas Items)
- `LayeredDrawable` — draw primitives grouped by layer with a render context.
- `Bounded` — world-space bounds for culling and hit testing.
- `HitTestable` — custom hit testing (defaults to bounds when available).
- `HaloProviding` — selection halo path.
- `Transformable` — position/rotation for drag and transforms.
- `CanvasConnectable` — expose connection points for the connection engine.
- `HandleEditable` — optional resize/shape handles for editor tools.

> A canvas item can conform to any subset of these. There is no "one true" base protocol.

## Connection System
- `ConnectionPoint` remains the domain-agnostic attachment point (world position + owner ID).
- `ConnectionEngine` manages edges/vertices and updates during drag.
- `CanvasConnectable` items provide connection points in world space.

## Editor Modes
- **Runtime (schematic/layout)**
  - Graph contains `CanvasSymbol` / `CanvasFootprint` only.
  - Pins/pads are rendered and exposed as connection points by the symbol/footprint.
  - Pins/pads are not separate graph nodes.

- **Editor (symbol/footprint editors)**
  - Graph contains `CanvasPrimitive`, `CanvasPin`, `CanvasPad` items for direct manipulation.
  - The editor builds/updates these items from the model and persists edits back.

## Rendering & Hit-Testing
- Rendering and hit-testing should operate on layered drawables and primitives.
- Avoid duplicate render paths; primitives should be drawn once per layer.
- Environment renderables are allowed only for non-selectable overlays.

## Data Flow
1. Model changes → graph rebuild/update of canvas items.
2. Canvas interactions mutate canvas items.
3. Graph deltas persist back into model (for runtime) or editor model (for symbol/footprint editor).

## Notes / Long-Term Cleanup
- Long-term: move `AnyCanvasPrimitive` out of core definitions into a model-agnostic primitive type.
- Keep the capability protocols (`Drawable`, `Bounded`, `Layerable`, `MultiLayerable`, `Transformable`) modular and compose them as needed.
