# CircuitPro Canvas Notes (Manhattan + Connections)

This is a lightweight snapshot of the current direction. Not a plan, just context.

## What We Moved Away From
- GraphEngine/GraphRuleset/GeometryPolicy pipeline in `CanvasKit/_Temp/Connection`.
- App-specific connection graph storage inside the framework.
- Runtime L‑shape rendering for edges that were stored as single diagonal segments.

## Current Connection Model
- Core protocols in CanvasKit:
  - `ConnectionPoint` (id + position)
  - `ConnectionLink` (startID/endID)
  - `ConnectionEngine` (`routes` + `normalize`)
  - `ConnectionDelta` for write‑back
- Links + points are stored explicitly as `CanvasItem`s.

## Manhattan Sandbox (Current State)
- `ManhattanWireEngine` routes only straight segments.
- `normalize(...)` does:
  - split non‑axis edges into two segments by inserting a corner `WireVertex`
  - merge colinear overlaps
- Normalization runs after drag (not on deserialization yet).
- Wire links are now stored explicitly as segments; no runtime L‑shape.

## What We Still Need to Do
- Run normalization on deserialization/import (optional, later).
- Consider intersection splitting to create explicit junctions.
- Migrate or retire old WireEngine/TraceEngine before deleting `_Temp/Connection`.
- Decide where to host additional normalize passes (engine internal vs shared helpers).

## Notes
- Connection stack is all structs/value types.
- Interactions handle user intent; engine handles topology cleanup.
