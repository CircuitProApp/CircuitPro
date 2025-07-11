# Legend:

Connection - High level concept containing either a single Segment or multiple Segments within a ConnectionGraph  
Segment - Edge with two endpoints V1 and V2  
Junction - Meeting point of multiple Segments (>2)  

En - Edge n (1, 2, 3, 4, …)  
Vn - Vertex n (1, 2, 3, 4, …)  

Tn - Tap n (1, 2, 3, 4, …)  
DT - DoubleTap  

SEL(E) - Selected Edge  
DEL - Delete  

Scope - Tool or Post, explained below  

## Preface:

ConnectionElement is the highest level Connection representation that holds ConnectionGraph, a lower level graph management system that contains most of the code related to inter-graph modifications.

The Connection behavior code is delegated through two stages, one within ConnectionTool Scope and one in CanvasInteractionController and CoreGraphicsCanvasView.

# Tests:

## Simple Connection Creation

- Scope: Tool  
- Action: T(0,0) DT(100,0)  
- Result: A single Connection Edge

## L-shape Connection Creation

- Scope: Tool  
- Action: T(0,0) DT(100,100)  
- Result: Two orthogonal Edges joined by one Vertex at endpoints. S1 0,0 100,0 S2 100,0 100,100

## Closed Connection Creation

- Scope: Tool  
- Logic: Vertex Merging  
- Action: T1(0,0) T2(100,0) T3(100,100) T4(0,100) T5(0,0)  
- Result: A single close looped Connection where the first Edge’s start Vertex and last Edge’s endpoint Vertex are the same

## Closed Connection Creation, L-shape variant

- Scope: Tool  
- Logic: Vertex Merging  
- Action: T1(0,0) T2(100,100) T3(0,0)  
- Result: A single close looped Connection where the first Edge’s start Vertex and last Edge’s endpoint Vertex are the same

## Closed Connection Dismantling

- Scope: Post  
- Precondition: An existing closed-loop Connection consisting of  
  - E1 from (0,0) to (100,0)  
  - E2 from (100,0) to (100,100)  
  - E3 from (100,100) to (0,100)  
  - E4 from (0,100) to (0,0)  
- Action: SEL(E3) DEL  
- Result: A C-shaped whole Connection

## Closed Connection Self-Intersection Creation

- Scope: Tool  
- Logic: Edge Split  
- Action: T1(0,0) T2(100,0) T3(100,100) T4(50,100) T5(50,0)  
- Result: A Connection that creates a T Junction with itself at 50,0

## Collinear Edge Merge

- Scope: Tool  
- Logic: Edge Merge  
- Action: T(0,0) T(100,0) DT(200,0)  
- Result: A uniform Edge

## Collinear Edge Merge Multi (>2)

- Scope: Tool  
- Logic: Edge Merge  
- Action: T1(0,0) T2(100,0) T3(200,0) DT(300,0)  
- Result: A uniform Edge

## Orthogonal Connection Graph Merge

- Scope: Tool & Post  
- Logic: Connection Merge  
- Precondition: An existing Edge consisting of  
  - E1 from (0,0) to (100,0)  
- Action: T1(100,100) T2(100,0)  
- Result: One uniform Connection with Edges that share a Vertex at 100,0

## T-Junction Creation

- Scope: Tool & Post  
- Logic: Edge Split  
- Precondition: An existing Edge consisting of  
  - E1 from (0,0) to (100,0)  

### Test 1 (Top-Down)

- Action: T1(50,100) DT(50,0)  
- Result: One uniform Connection with a T Junction where three Edges share one Vertex

### Test 2 (Bottom-Up)

- Action: T1(50,0) DT(50,100)  
- Result: One uniform Connection with a T Junction where three Edges share one Vertex

## T-Junction Dismantling

- Scope: Post  
- Logic: Edge Merge  
- Precondition: An existing T-junction consisting of  
  - E1 from (0,0) to (100,0)  
  - E2 from (100,100) to (100,0)  
  - E3 from (200,0) to (100,0)  

### Test 1

- Action: SEL(E1) DEL  
- Result: An L-shaped Connection

### Test 2

- Action: SEL(E2) DEL  
- Result: A complete Edge  
  - Addendum: In case either Edge connected with others, upon deletion resulting Connections should not exceed 2

## Collinear Half-Interior-Overlap Edge Merge

- Scope: Tool & Post  
- Logic: Edge Merge (half interior)  
- Precondition: An existing Edge consisting of  
  - E1 from (0,0) to (100,0)  
- Action: T1(200,0) DT(50,0)  
- Result: One continuous Edge from (0,0) to (200,0), with the overlapping region merged seamlessly

## Collinear Full-Interior-Overlap Edge Merge

- Scope: Tool & Post  
- Logic: Edge Merge (full interior)  
- Precondition: An existing Edge consisting of  
  - E1 from (0,0) to (200,0)  
- Action: T1(150,0) T2(50,0)  
- Result: One continuous Edge from (0,0) to (200,0), with the overlapping region merged seamlessly

## Edge & Vertex Full-Interior Merge

- Scope: Tool & Post  
- Logic: Edge Merge + Vertex Merge (full interior)  
- Precondition: An existing Edge consisting of  
  - E1 from (0,0) to (100,0)  
- Action: T1(200,0) T2(0,0)  
- Result: One continuous Edge from (0,0) to (200,0), with the entire original Segment merged, and the 0,0 Vertex unified

## Edge & Vertex Half-Interior Merge

- Scope: Tool & Post  
- Logic: Edge Merge + Vertex Merge (half interior)  
- Precondition: An existing Edge consisting of  
  - E1 from (0,0) to (100,0)  
- Action: T1(50,0) T2(0,0)  
- Result: One continuous Edge from (0,0) to (100,0), with the overlapping half merged seamlessly, and the 0,0 Vertex unified

## Collinear Merge on T‑Junction

- Scope: Tool & Post  
- Logic: Edge Merge + Vertex Merge (collinear on Junction)  
- Precondition: An existing T‑Junction consisting of  
  - E1 from (0,0) to (100,0)  
  - E2 from (100,100) to (100,0)  
  - E3 from (200,0) to (100,0)  
- Action: T1(300,0) DT(100,0)  
- Result: One continuous horizontal Edge from (0,0) to (300,0), with the new Segment merged into the existing chain and the vertical branch at (100,0) preserved

## Collinear Merge on T‑Junction (Reverse Endpoint)

- Scope: Tool & Post  
- Logic: Edge Merge + Vertex Merge (collinear on Junction)  
- Precondition: An existing T‑Junction consisting of  
  - E1 from (0,0) to (100,0)  
  - E2 from (100,100) to (100,0)  
  - E3 from (200,0) to (100,0)  
- Action: T1(300,0) DT(0,0)  
- Result: One continuous horizontal Edge from (0,0) to (300,0), with the entire original E1 merged, both endpoints unified into the existing Vertex at (0,0), and the vertical branch still attached at (100,0)

## H-Junction Creation

- Scope: Tool & Post

### Test 1

- Logic: Multi-Junction (H pattern)  
- Precondition: Existing horizontal Edges  
  - E1 from (0,0) to (100,0)  
  - E2 from (0,100) to (100,100)  
- Action: T1(50,0) DT(50,100)  
- Result: A Connection in the shape of an "H", where the newly created vertical Edge intersects both horizontals at (50,0) and (50,100)

### Test 2 (Variant: Additional Vertical Bar)

- Logic: Multi-Junction Extension  
- Precondition: Result of Test 1 (the H-Junction)  
- Action: T6(25,0) DT(25,100)  
- Result: Two vertical Edges at x=25 and x=50 connecting the same horizontal Edges, forming a double-barred “H” pattern
