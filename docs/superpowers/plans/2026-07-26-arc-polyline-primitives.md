# Arc + Polyline Primitive Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `CanvasArc` and `CanvasPolyline` as real `CanvasPrimitive` types, following the existing `CanvasLine`/`CanvasRectangle`/`CanvasCircle` pattern exactly, so CircuitPro can represent the geometry KiCad symbols/footprints rely on.

**Architecture:** Two new value-type structs in `Model/Primitive/`, wired into `AnyCanvasPrimitive` (the type-erased enum every part of the app already switches on), `PrimitiveGeometry` (path generation), and one new `CKView` render type per primitive, mirroring `CircleView`. Rendering resolves color from the active layer at render time — never stored on the primitive — same as every existing primitive.

**Tech Stack:** Swift, SwiftUI, CanvasKit (this repo's custom AppKit/CALayer-backed rendering framework).

## Global Constraints

- Match the existing `CanvasLine`/`CanvasRectangle`/`CanvasCircle` pattern exactly at every integration point — do not invent a different shape for how Arc/Polyline plug in.
- No new interactive tools (`ArcTool`/`PolylineTool`) — out of scope for this plan.
- No per-vertex/per-handle editing (dragging individual polyline points or arc angle handles) — out of scope. Primitives get whole-shape select/drag/delete only, same baseline as other primitives without dedicated handle logic.
- Placeholder built-in SF Symbol icon names are fine; no new asset-catalog work.
- This project has no XCTest target (see `CLAUDE.md`) — verification is `xcodebuild build` (compile-correctness) after each task, plus a final manual visual-verification task that exercises the running app.
- Spec: `docs/superpowers/specs/2026-07-26-arc-polyline-primitives-design.md`

---

### Task 1: Add `CanvasArc` and `CanvasPolyline` data models

**Files:**
- Create: `CircuitPro/Model/Primitive/CanvasArc.swift`
- Create: `CircuitPro/Model/Primitive/CanvasPolyline.swift`

**Interfaces:**
- Produces: `CanvasArc` (`id`, `radius`, `startAngle`, `endAngle`, `position`, `rotation`, `strokeWidth`, `filled`, `layerId`) and `CanvasPolyline` (`id`, `points`, `isClosed`, `position`, `rotation`, `strokeWidth`, `filled`, `layerId`), both conforming to `CanvasPrimitive` (`Transformable, Identifiable, Codable, Equatable, Hashable, Layerable`). Later tasks construct and pattern-match these directly.

- [ ] **Step 1: Create `CanvasArc.swift`**

```swift
//
//  CanvasArc.swift
//  CircuitPro
//

import CoreGraphics
import Foundation

struct CanvasArc: CanvasPrimitive {

    let id: UUID
    var radius: CGFloat
    var startAngle: CGFloat
    var endAngle: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool

    var layerId: UUID?

    init(
        id: UUID = UUID(),
        radius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat,
        position: CGPoint,
        rotation: CGFloat = 0,
        strokeWidth: CGFloat,
        filled: Bool = false,
        layerId: UUID?
    ) {
        self.id = id
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.position = position
        self.rotation = rotation
        self.strokeWidth = strokeWidth
        self.filled = filled
        self.layerId = layerId
    }
}

extension CanvasArc: CanvasItem {}
```

- [ ] **Step 2: Create `CanvasPolyline.swift`**

```swift
//
//  CanvasPolyline.swift
//  CircuitPro
//

import CoreGraphics
import Foundation

struct CanvasPolyline: CanvasPrimitive {

    let id: UUID
    var points: [CGPoint]
    var isClosed: Bool
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool

    var layerId: UUID?

    init(
        id: UUID = UUID(),
        points: [CGPoint],
        isClosed: Bool = false,
        position: CGPoint,
        rotation: CGFloat = 0,
        strokeWidth: CGFloat,
        filled: Bool = false,
        layerId: UUID?
    ) {
        self.id = id
        self.points = points
        self.isClosed = isClosed
        self.position = position
        self.rotation = rotation
        self.strokeWidth = strokeWidth
        self.filled = filled
        self.layerId = layerId
    }
}

extension CanvasPolyline: CanvasItem {}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project CircuitPro.xcodeproj -scheme CircuitPro -configuration Debug build`
Expected: `** BUILD SUCCEEDED **` (these two files aren't referenced anywhere yet, so this only checks they're syntactically and semantically valid on their own).

- [ ] **Step 4: Commit**

```bash
git add CircuitPro/Model/Primitive/CanvasArc.swift CircuitPro/Model/Primitive/CanvasPolyline.swift
git commit -m "Add CanvasArc and CanvasPolyline data models"
```

---

### Task 2: Integrate `CanvasArc` end-to-end

Wires `CanvasArc` into every place `AnyCanvasPrimitive` is exhaustively switched on: the enum itself, geometry, rendering, the primitive-type switch view, and the inspector. `CanvasPolyline` is *not* touched in this task — the enum only gains a `.arc` case, so all switches stay exhaustive without needing `.polyline` yet.

**Files:**
- Modify: `CircuitPro/Model/Primitive/AnyCanvasPrimitive.swift`
- Modify: `CircuitPro/Model/Primitive/PrimitiveGeometry.swift`
- Modify: `CircuitPro/App/Resources/CircuitProSymbols.swift`
- Create: `CircuitPro/Features/CanvasKit+CircuitPro/View/Primitive/ArcView.swift`
- Modify: `CircuitPro/Features/CanvasKit+CircuitPro/View/Primitive/PrimitiveView.swift`
- Modify: `CircuitPro/Features/ComponentDesign/Inspectors/Elements/PrimitivePropertiesView.swift`

**Interfaces:**
- Consumes: `CanvasArc` from Task 1.
- Produces: `AnyCanvasPrimitive.arc(CanvasArc)` case, fully wired; `ArcView` (`CKView`, takes `arc: CanvasArc, isEditable: Bool`); `ArcPropertiesView` (`View`, takes `@Binding var arc: CanvasArc`). Task 4 constructs `AnyCanvasPrimitive.arc(...)` directly to verify.

- [ ] **Step 1: Add the `.arc` case and wire it into every computed property in `AnyCanvasPrimitive.swift`**

Add `case arc(CanvasArc)` to the enum, then extend each switch. The full set of edits:

```swift
enum AnyCanvasPrimitive: CanvasPrimitive, Identifiable, Hashable {

    case line(CanvasLine)
    case rectangle(CanvasRectangle)
    case circle(CanvasCircle)
    case arc(CanvasArc)

    var id: UUID {
        switch self {
        case .line(let line): return line.id
        case .rectangle(let rectangle): return rectangle.id
        case .circle(let circle): return circle.id
        case .arc(let arc): return arc.id
        }
    }

    var layerId: UUID? {
        get {
            switch self {
            case .line(let primitive): return primitive.layerId
            case .rectangle(let primitive): return primitive.layerId
            case .circle(let primitive): return primitive.layerId
            case .arc(let primitive): return primitive.layerId
            }
        }
        set {
            switch self {
            case .line(var primitive):
                primitive.layerId = newValue
                self = .line(primitive)
            case .rectangle(var primitive):
                primitive.layerId = newValue
                self = .rectangle(primitive)
            case .circle(var primitive):
                primitive.layerId = newValue
                self = .circle(primitive)
            case .arc(var primitive):
                primitive.layerId = newValue
                self = .arc(primitive)
            }
        }
    }

    var position: CGPoint {
        get {
            switch self {
            case .line(let line): return line.position
            case .rectangle(let rectangle): return rectangle.position
            case .circle(let circle): return circle.position
            case .arc(let arc): return arc.position
            }
        }
        set {
            switch self {
            case .line(var line):
                line.position = newValue
                self = .line(line)
            case .rectangle(var rectangle):
                rectangle.position = newValue
                self = .rectangle(rectangle)
            case .circle(var circle):
                circle.position = newValue
                self = .circle(circle)
            case .arc(var arc):
                arc.position = newValue
                self = .arc(arc)
            }
        }
    }

    var rotation: CGFloat {
        get {
            switch self {
            case .line(let line): return line.rotation
            case .rectangle(let rectangle): return rectangle.rotation
            case .circle(let circle): return circle.rotation
            case .arc(let arc): return arc.rotation
            }
        }
        set {
            switch self {
            case .line(var line):
                line.rotation = newValue
                self = .line(line)
            case .rectangle(var rectangle):
                rectangle.rotation = newValue
                self = .rectangle(rectangle)
            case .circle(var circle):
                circle.rotation = newValue
                self = .circle(circle)
            case .arc(var arc):
                arc.rotation = newValue
                self = .arc(arc)
            }
        }
    }

    var strokeWidth: CGFloat {
        get {
            switch self {
            case .line(let line): return line.strokeWidth
            case .rectangle(let rectangle): return rectangle.strokeWidth
            case .circle(let circle): return circle.strokeWidth
            case .arc(let arc): return arc.strokeWidth
            }
        }
        set {
            switch self {
            case .line(var line):
                line.strokeWidth = newValue
                self = .line(line)
            case .rectangle(var rectangle):
                rectangle.strokeWidth = newValue
                self = .rectangle(rectangle)
            case .circle(var circle):
                circle.strokeWidth = newValue
                self = .circle(circle)
            case .arc(var arc):
                arc.strokeWidth = newValue
                self = .arc(arc)
            }
        }
    }

    var filled: Bool {
        get {
            switch self {
            case .line(let line): return line.filled
            case .rectangle(let rectangle): return rectangle.filled
            case .circle(let circle): return circle.filled
            case .arc(let arc): return arc.filled
            }
        }
        set {
            switch self {
            case .line(var line):
                line.filled = newValue
                self = .line(line)
            case .rectangle(var rectangle):
                rectangle.filled = newValue
                self = .rectangle(rectangle)
            case .circle(var circle):
                circle.filled = newValue
                self = .circle(circle)
            case .arc(var arc):
                arc.filled = newValue
                self = .arc(arc)
            }
        }
    }
}
```

Then extend the `displayName` and `symbol` extensions further down the same file:

```swift
extension AnyCanvasPrimitive {
    var displayName: String {
        switch self {
        case .rectangle:
            "Rectangle"
        case .circle:
            "Circle"
        case .line:
            "Line"
        case .arc:
            "Arc"
        }
    }
}

extension AnyCanvasPrimitive {
    var symbol: String {
        switch self {
        case .rectangle:
            CircuitProSymbols.Graphic.rectangle
        case .circle:
            CircuitProSymbols.Graphic.circle
        case .line:
            CircuitProSymbols.Graphic.line
        case .arc:
            CircuitProSymbols.Graphic.arc
        }
    }
}
```

And add a binding accessor next to `.rectangle`/`.circle`/`.line` in the `Binding where Value == AnyCanvasPrimitive` extension at the bottom of the file:

```swift
    var arc: Binding<CanvasArc>? {
        guard case .arc = self.wrappedValue else { return nil }
        return Binding<CanvasArc>(
            get: {
                if case .arc(let value) = self.wrappedValue {
                    return value
                } else {
                    fatalError("The primitive is no longer an arc.")
                }
            },
            set: { self.wrappedValue = .arc($0) }
        )
    }
```

- [ ] **Step 2: Add the `.arc` icon constant to `CircuitProSymbols.swift`**

Modify the `Graphic` enum:

```swift
    enum Graphic {
        static let line = "line.diagonal"
        static let rectangle = "rectangle"
        static let circle = "circle"
        static let arc = "circle.bottomhalf.filled"

        static let cursor = "cursorarrow"
        static let ruler = "ruler"
    }
```

- [ ] **Step 3: Add the arc case to `PrimitiveGeometry.localPath`**

Add this case inside the existing `switch primitive` in `localPath(for:)` (no other changes needed — `localBoundingBox` already derives generically from `localPath`):

```swift
        case .arc(let arc):
            let path = CGMutablePath()
            path.addArc(
                center: .zero,
                radius: arc.radius,
                startAngle: arc.startAngle,
                endAngle: arc.endAngle,
                clockwise: false
            )
            if arc.filled {
                path.closeSubpath()
            }
            return path
```

- [ ] **Step 4: Create `ArcView.swift`**

Mirrors `CircleView.swift` structurally — same halo/color-resolution pattern, geometry built via `PrimitiveGeometry.localPath` wrapped in `CKPath` instead of a dedicated `CKArc` framework type (matching how `WireView`/`TraceView` already render arbitrary geometry). No handles — per-shape editing is out of scope for this plan.

```swift
import AppKit

struct ArcView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let arc: CanvasArc
    let isEditable: Bool

    var showHalo: Bool {
        context.highlightedItemIDs.contains(arc.id) ||
            context.selectedItemIDs.contains(arc.id)
    }

    var body: some CKView {
        let path = PrimitiveGeometry.localPath(for: .arc(arc))
        CKGroup {
            CKPath(path: path)
                .fill(arc.filled ? strokeColor : .clear)
                .stroke(strokeColor, width: arc.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)
        }
    }

    private var strokeColor: CGColor {
        context.layers.first { $0.id == arc.layerId }?.color
            ?? environment.canvasTheme.textColor
    }
}
```

- [ ] **Step 5: Wire `ArcView` into `PrimitiveView.swift`**

Add this case to the `switch primitive` in `PrimitiveView.body`:

```swift
        case .arc(let arc):
            ArcView(
                arc: arc,
                isEditable: isEditable
            )
            .position(arc.position)
            .rotation(arc.rotation)
```

- [ ] **Step 6: Add `ArcPropertiesView` and wire it into `PrimitivePropertiesView.swift`**

Add the case to the switch in `PrimitivePropertiesView.body`:

```swift
            case .arc:
                if let arcBinding = $primitive.arc {
                    ArcPropertiesView(arc: arcBinding)
                }
```

Add the new view alongside `RectanglePropertiesView`/`CirclePropertiesView`/`LinePropertiesView` in the same file:

```swift
struct ArcPropertiesView: View {
    @Binding var arc: CanvasArc

    private var startAngleDegrees: Binding<CGFloat> {
        Binding(
            get: { arc.startAngle * 180 / .pi },
            set: { arc.startAngle = $0 * .pi / 180 }
        )
    }

    private var endAngleDegrees: Binding<CGFloat> {
        Binding(
            get: { arc.endAngle * 180 / .pi },
            set: { arc.endAngle = $0 * .pi / 180 }
        )
    }

    var body: some View {

        InspectorSection("Transform") {

            PointControlView(
                title: "Center",
                point: $arc.position,
                displayOffset: PaperSize.component.centerOffset()
            )

            InspectorRow("Radius", style: .leading) {
                InspectorNumericField(value: $arc.radius, unit: "mm")
            }

            InspectorRow("Angles", style: .leading) {
                InspectorNumericField(label: "Start", value: startAngleDegrees, maxDecimalPlaces: 1, unit: "°")
                InspectorNumericField(label: "End", value: endAngleDegrees, maxDecimalPlaces: 1, unit: "°")
            }

            RotationControlView(object: $arc)

        }

        Divider()
        PrimitiveStyleControlView(object: $arc)

    }
}
```

- [ ] **Step 7: Build to verify it compiles**

Run: `xcodebuild -project CircuitPro.xcodeproj -scheme CircuitPro -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add CircuitPro/Model/Primitive/AnyCanvasPrimitive.swift \
        CircuitPro/Model/Primitive/PrimitiveGeometry.swift \
        CircuitPro/App/Resources/CircuitProSymbols.swift \
        CircuitPro/Features/CanvasKit+CircuitPro/View/Primitive/ArcView.swift \
        CircuitPro/Features/CanvasKit+CircuitPro/View/Primitive/PrimitiveView.swift \
        CircuitPro/Features/ComponentDesign/Inspectors/Elements/PrimitivePropertiesView.swift
git commit -m "Integrate CanvasArc into AnyCanvasPrimitive, rendering, and inspector"
```

---

### Task 3: Integrate `CanvasPolyline` end-to-end

Same shape as Task 2, for the second primitive type. Adds the `.polyline` case last, so switches go from exhaustive-with-4-cases to exhaustive-with-5-cases.

**Files:**
- Modify: `CircuitPro/Model/Primitive/AnyCanvasPrimitive.swift`
- Modify: `CircuitPro/Model/Primitive/PrimitiveGeometry.swift`
- Modify: `CircuitPro/App/Resources/CircuitProSymbols.swift`
- Create: `CircuitPro/Features/CanvasKit+CircuitPro/View/Primitive/PolylineView.swift`
- Modify: `CircuitPro/Features/CanvasKit+CircuitPro/View/Primitive/PrimitiveView.swift`
- Modify: `CircuitPro/Features/ComponentDesign/Inspectors/Elements/PrimitivePropertiesView.swift`

**Interfaces:**
- Consumes: `CanvasPolyline` from Task 1.
- Produces: `AnyCanvasPrimitive.polyline(CanvasPolyline)` case, fully wired; `PolylineView` (`CKView`, takes `polyline: CanvasPolyline, isEditable: Bool`); `PolylinePropertiesView` (`View`, takes `@Binding var polyline: CanvasPolyline`). Task 4 constructs `AnyCanvasPrimitive.polyline(...)` directly to verify.

- [ ] **Step 1: Add the `.polyline` case and wire it into every computed property in `AnyCanvasPrimitive.swift`**

Add `case polyline(CanvasPolyline)` to the enum (after `.arc`), then add a `case .polyline(let primitive): return primitive.<field>` (or the `var`/reassignment equivalent for setters) arm to each of the six switches from Task 2 Step 1 (`id`, `layerId` get/set, `position` get/set, `rotation` get/set, `strokeWidth` get/set, `filled` get/set). Follow the exact same shape as the `.arc` arm added in Task 2 — e.g. for `id`:

```swift
    var id: UUID {
        switch self {
        case .line(let line): return line.id
        case .rectangle(let rectangle): return rectangle.id
        case .circle(let circle): return circle.id
        case .arc(let arc): return arc.id
        case .polyline(let polyline): return polyline.id
        }
    }
```

...and identically for `layerId`, `position`, `rotation`, `strokeWidth`, `filled` (both getter and setter branches), each getting one more `case .polyline(...):` arm using `polyline` as the bound variable name.

Then extend `displayName`:

```swift
extension AnyCanvasPrimitive {
    var displayName: String {
        switch self {
        case .rectangle:
            "Rectangle"
        case .circle:
            "Circle"
        case .line:
            "Line"
        case .arc:
            "Arc"
        case .polyline:
            "Polyline"
        }
    }
}
```

...and `symbol`:

```swift
extension AnyCanvasPrimitive {
    var symbol: String {
        switch self {
        case .rectangle:
            CircuitProSymbols.Graphic.rectangle
        case .circle:
            CircuitProSymbols.Graphic.circle
        case .line:
            CircuitProSymbols.Graphic.line
        case .arc:
            CircuitProSymbols.Graphic.arc
        case .polyline:
            CircuitProSymbols.Graphic.polyline
        }
    }
}
```

And add the binding accessor next to the `.arc` one added in Task 2:

```swift
    var polyline: Binding<CanvasPolyline>? {
        guard case .polyline = self.wrappedValue else { return nil }
        return Binding<CanvasPolyline>(
            get: {
                if case .polyline(let value) = self.wrappedValue {
                    return value
                } else {
                    fatalError("The primitive is no longer a polyline.")
                }
            },
            set: { self.wrappedValue = .polyline($0) }
        )
    }
```

- [ ] **Step 2: Add the `.polyline` icon constant to `CircuitProSymbols.swift`**

```swift
    enum Graphic {
        static let line = "line.diagonal"
        static let rectangle = "rectangle"
        static let circle = "circle"
        static let arc = "circle.bottomhalf.filled"
        static let polyline = "scribble"

        static let cursor = "cursorarrow"
        static let ruler = "ruler"
    }
```

- [ ] **Step 3: Add the polyline case to `PrimitiveGeometry.localPath`**

```swift
        case .polyline(let polyline):
            let path = CGMutablePath()
            guard let first = polyline.points.first else { return path }
            path.move(to: first)
            for point in polyline.points.dropFirst() {
                path.addLine(to: point)
            }
            if polyline.isClosed {
                path.closeSubpath()
            }
            return path
```

- [ ] **Step 4: Create `PolylineView.swift`**

Same structure as `ArcView.swift`:

```swift
import AppKit

struct PolylineView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let polyline: CanvasPolyline
    let isEditable: Bool

    var showHalo: Bool {
        context.highlightedItemIDs.contains(polyline.id) ||
            context.selectedItemIDs.contains(polyline.id)
    }

    var body: some CKView {
        let path = PrimitiveGeometry.localPath(for: .polyline(polyline))
        CKGroup {
            CKPath(path: path)
                .fill(polyline.filled ? strokeColor : .clear)
                .stroke(strokeColor, width: polyline.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)
        }
    }

    private var strokeColor: CGColor {
        context.layers.first { $0.id == polyline.layerId }?.color
            ?? environment.canvasTheme.textColor
    }
}
```

- [ ] **Step 5: Wire `PolylineView` into `PrimitiveView.swift`**

```swift
        case .polyline(let polyline):
            PolylineView(
                polyline: polyline,
                isEditable: isEditable
            )
            .position(polyline.position)
            .rotation(polyline.rotation)
```

- [ ] **Step 6: Add `PolylinePropertiesView` and wire it into `PrimitivePropertiesView.swift`**

```swift
            case .polyline:
                if let polylineBinding = $primitive.polyline {
                    PolylinePropertiesView(polyline: polylineBinding)
                }
```

```swift
struct PolylinePropertiesView: View {
    @Binding var polyline: CanvasPolyline

    var body: some View {

        InspectorSection("Transform") {

            PointControlView(
                title: "Position",
                point: $polyline.position,
                displayOffset: PaperSize.component.centerOffset()
            )

            RotationControlView(object: $polyline)

            InspectorRow("Points") {
                Text("\(polyline.points.count)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            InspectorRow("Closed") {
                Toggle("Closed", isOn: $polyline.isClosed)
                    .labelsHidden()
            }

        }

        Divider()
        PrimitiveStyleControlView(object: $polyline)

    }
}
```

(Per-vertex editing of `points` is out of scope — this shows the point count read-only.)

- [ ] **Step 7: Build to verify it compiles**

Run: `xcodebuild -project CircuitPro.xcodeproj -scheme CircuitPro -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add CircuitPro/Model/Primitive/AnyCanvasPrimitive.swift \
        CircuitPro/Model/Primitive/PrimitiveGeometry.swift \
        CircuitPro/App/Resources/CircuitProSymbols.swift \
        CircuitPro/Features/CanvasKit+CircuitPro/View/Primitive/PolylineView.swift \
        CircuitPro/Features/CanvasKit+CircuitPro/View/Primitive/PrimitiveView.swift \
        CircuitPro/Features/ComponentDesign/Inspectors/Elements/PrimitivePropertiesView.swift
git commit -m "Integrate CanvasPolyline into AnyCanvasPrimitive, rendering, and inspector"
```

---

### Task 4: Manual visual verification

There's no hand-drawing tool for these yet (by design — see spec), so the only way to see them rendered is to seed a couple of instances directly into a canvas's item list, run the app, and look. This step is deliberately **not committed** — it's a throwaway probe, discarded once confirmed.

**Files:**
- Temporarily modify (do not commit): `CircuitPro/Features/ComponentDesign/Manager/ComponentDesignManager.swift`

- [ ] **Step 1: Temporarily seed an arc and a polyline into the symbol editor**

In `ComponentDesignManager.init()`, temporarily add:

```swift
    init() {
        #if DEBUG
        symbolEditor.items = [
            AnyCanvasPrimitive.arc(CanvasArc(
                radius: 20,
                startAngle: 0,
                endAngle: .pi,
                position: CGPoint(x: 400, y: 300),
                strokeWidth: 1,
                layerId: nil
            )),
            AnyCanvasPrimitive.polyline(CanvasPolyline(
                points: [
                    CGPoint(x: -20, y: -20),
                    CGPoint(x: 20, y: -20),
                    CGPoint(x: 0, y: 20),
                ],
                isClosed: true,
                position: CGPoint(x: 500, y: 300),
                strokeWidth: 1,
                filled: true,
                layerId: nil
            )),
        ]
        #endif
    }
```

- [ ] **Step 2: Build and launch the app**

Run: `xcodebuild -project CircuitPro.xcodeproj -scheme CircuitPro -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`

Launch the built app (`Window → Component Design`, or the "Component Design" window from the app's Window menu) and open the Symbol canvas.

- [ ] **Step 3: Visually confirm rendering**

Check, on the Symbol canvas:
- A half-circle arc renders near (400, 300) with a visible stroke.
- A filled triangle (closed, filled polyline) renders near (500, 300).
- Clicking either selects it (halo appears) and it can be dragged as a whole.
- Deleting a selected one removes it from the canvas.

- [ ] **Step 4: Discard the temporary seed**

```bash
git checkout -- CircuitPro/Features/ComponentDesign/Manager/ComponentDesignManager.swift
git status
```

Expected: clean working tree (no output from `git status` beyond "nothing to commit").

---

## Follow-on work (not this plan)

- `ArcTool` / `PolylineTool` for hand-drawing.
- Per-vertex / per-handle reshaping.
- KiCad symbol library import (`.kicad_sym` → `SymbolDefinition`) — separate spec, depends on this plan being complete.
