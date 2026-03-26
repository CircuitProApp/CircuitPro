# Connection Drag Architecture

## Goal

Make connection dragging easier to evolve by sharing the drag lifecycle and small movement primitives, while keeping wire and trace geometry behavior separate.

## Scope

This document is about edge dragging only:

- `begin`
- `changed`
- `end`

It is not about routing creation, preview rendering, or normalization rules outside drag.

## Current Direction

Use sibling drag controllers with the same outer shape:

- `WireEdgeDragController`
- `TraceEdgeDragController`

Both should conform to the same narrow lifecycle boundary:

- start a drag session
- update a drag session
- end a drag session

The view should only orchestrate:

- forward drag events
- own controller state via `@CKState`
- run normalization after drag ends

## What Should Be Shared

Share structure and primitives, not full drag algorithms.

Good shared pieces:

- drag lifecycle shape
- drag session state patterns
- orientation classification helpers
- adjacency / endpoint map building
- fixed-endpoint detachment helpers
- support-line / intersection helpers
- collapse / crossing detection helpers

## What Should Stay Separate

Keep geometry policy mode-specific.

Wire owns:

- orthogonal movement rules
- its propagation behavior
- any wire-specific detach or stability rules

Trace owns:

- octilinear movement rules
- trace-specific propagation / transition behavior
- trace-specific collapse or axis-flip behavior

Do not force wire and trace to share one solver.

## Mental Model

Drag should be organized as:

1. `begin = snapshot`
2. `changed = propagate + local transition if invalid`
3. `end = normalize`

This is the main alignment target between wire and trace.

## Primitive-First Refactor Rule

When looking for reuse, extract only code that can be named without saying `wire` or `trace`.

Examples:

- move endpoint
- move segment by delta
- classify orientation
- intersect support lines
- detach fixed endpoint
- detect zero-length / crossed support

If a function depends on routing policy or special drag semantics, keep it mode-specific.

## Validation

Use `TRACES.md` as acceptance coverage for trace behavior.

Use wire drag as the reference for interaction stability and controller structure, not as the source of trace geometry rules.
