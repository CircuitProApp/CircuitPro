# CanvasKit Architecture Roadmap

## Current Status
- CoreConnection module created ✓
- Dead code cleanup done ✓
- Unified DragInteraction created ✓

---

## Target Architecture

### Layer 1: CanvasKit (Framework — Domain-Agnostic)
```
CanvasKit/
├── CoreConnection/           # Connection management
│   ├── ConnectionEngine      # Protocol for connection systems
│   └── ConnectionPoint       # Protocol for anchor points
├── Model/Protocol/           # Canvas element protocols
│   ├── CanvasRenderable      # Draw + bounds + hit test
│   └── CanvasDraggable       # Move + position
├── Interaction/              # Unified interaction handling
│   └── DragInteraction       # ONE drag handler
└── ...
```

### Layer 2: CircuitPro (App Implementation)
```
Features/Canvas/
├── ComponentInstance+CanvasRenderable   # Symbols conform to protocols
├── WireEngine                           # Conforms to ConnectionEngine
└── Graph/                               # Internal state for connections
```

---

## Phase 1: CanvasRenderable Migration ✓

- [x] `ComponentInstance` conforms to `CanvasRenderable` + `CanvasDraggable`
- [x] Removed legacy symbol render/halo/hit-test providers
- [x] Fixed double-rendering bug (pins/text)
- [x] Junction dots moved to wire rendering

---

## Phase 2: Unified Drag Interaction ✓

- [x] Merged `CanvasDraggableInteraction` into `DragInteraction`
- [x] Priority order: Items → Connections → Text
- [x] Deleted `CanvasDraggableInteraction.swift`

---

## Phase 3: Graph Component Cleanup (IN PROGRESS)

### For Schematic Editor:
- [ ] Remove `GraphSymbolComponent` sync (symbols use protocol now)
- [ ] Keep `GraphTextComponent` for text editing (Ctrl+drag anchor)
- [x] Keep wire/trace components (internal to ConnectionEngine)

### For Component Editors:
- [ ] Migrate `SymbolCanvasView` to use `CanvasRenderable` for primitives
- [ ] Migrate `FootprintCanvasView` to use `CanvasRenderable`

---

## Phase 4: CoreConnection Integration

- [ ] Make `PinDefinition` conform to `ConnectionPoint`
- [ ] Have `TraceEngine` conform to `ConnectionEngine`
- [ ] Unify wire/trace handling under `ConnectionEngine` protocol

---

## Phase 5: Final Cleanup

- [ ] Remove unused graph components and providers
- [ ] Simplify `CanvasView` API
- [ ] Document the architecture for future development
