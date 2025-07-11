# Legend:

Connection - High level concept containing either a single segment or multiple segments within a connection graph
Segment - Edge with two endpoints V1 and V2
Junction - Meeting point of multiple segments (>2)

En - Edge n (1, 2, 3, 4, …)
Vn - Vertex n (1, 2, 3, 4, …)

Tn - Tap n (1, 2, 3, 4, …)
DT - Double Tap

SEL(E) - Selected Edge
BKSP - Delete 

Scope - Tool or Post, explained below

## Preface:
ConnectionElement is the highest level Connection representation that holds ConnectionGraph, a lower level graph management system that contains most of the code related to iner-graph modifications.

The connection behavior code is delegated through two stages, one within ConnectionTool scope and one in CanvasInteractionController and CoreGraphicsCanvasView.

# Tests:

## Simple Connection Creation
- Scope: Tool
- Action: T@ 0,0 DT@ 100,0
- Result: A single connection edge

## L-shape Connection Creation
- Scope: Tool
- Action: T@ 0,0 DT@ 100,100
- Result: Two orthogonal edges joined by one vertex at endpoints. S1 0,0 100,0 S2 100,0 100,100

## Closed Connection Creation
- Scope: Tool
- Logic: Vertex Merging
- Action: T1@ 0,0 T2@ 100,0 T3@ 100,100 T4@ 0,100 T5@ 0,0
- Result: A single close looped connection where the first edge’s start vertex and last edge’s endpoint vertex are the same

## Closed Connection Creation, L-shape variant
- Scope: Tool
- Logic: Vertex Merging
- Action: T1@ 0,0 T2@ 100,100 T3@ 0,0
- Result: A single close looped connection where the first edge’s start vertex and last edge’s endpoint vertex are the same

## Closed Connection Dismantling
- Scope: Post
- Precondition: A closed-loop connection 0,0 100,0 100,100 0,100
- Action: SEL(E3 [100,0 100,100]) BKSP
- Result: A C-shaped whole connection

## Closed Connection Self-Intersection Creation
- Scope: Tool
- Logic: Edge Split
- Action: T1@ 0,0 T2@ 100,0 T3@ 100,100 T4@ 50,100 T5@ 50,0
- Result: A connection that creates a T junction with itself at 50,0

## Collinear Edge Merge
- Scope: Tool
- Logic: Edge Merge
- Action: Tap at (0,0), tap at (100,0) to create the first segment, then double-tap at (200,0) to extend and merge
    - T1@ 0,0 T2@ 100,0 DT@ 200,0
- Result: A uniform edge

## Collinear Edge Merge Multi (>2)
- Scope: Tool
- Logic: Edge Merge
- Action: Tap sequentially at (0,0), (100,0), (200,0) then double-tap at (300,0) to merge all into one
    - T1@ 0,0 T2@ 100,0 T3@ 200,0 DT@ 300,0
- Result: A uniform edge

## Orthogonal Connection Graph Merge
- Scope: Tool & Post
- Logic: Connection Merge
- Precondition: Existing Edge from a separate tool call E1 0,0 100,0
- Action: Tap at (100,100) then tap at (100,0) to join the new segment into the existing graph
    - T1@ 100,100 T2@ 100,0
- Result: One uniform connection with edges that share a vertex at 100,0

## T-Junction Creation
- Scope: Tool & Post
- Logic: Edge Split
- Precondition: Existing Edge from a separate tool call E1 0,0 100,0
- Action: Tap at (50,100) then double-tap at (50,0) to split the existing edge and form a T
    - T1@ 50,100 DT@ 50,0
- Result: One uniform connection with a T shape junction where three edges share one vertex

## T-Junction Dismantling
- Scope: Post
- Logic: Edge Merge
- Precondition: Existing T-Junction E1 0,0 100,0 E2 100,100 100,0 E3 200,0 100,0  
### Test 1
- Action: Select the first horizontal edge and delete to leave an L-shape
    - SEL(E1) BKSP
- Result: An L-shaped connection  
### Test 2
- Action: Select the vertical edge and delete to merge into a single line
    - SEL(E2) BKSP
- Result: A complete edge  
*Addendum: In case either Edge connected with others, upon deletion resulting Connections should not exceed 2*

## Collinear Half-Interior-Overlap Edge Merge
- Scope: Tool & Post
- Logic: Edge Merge (half interior)
- Precondition: An existing edge E1 from (0,0) to (100,0)
- Action: Draw a second edge that overlaps the middle of E1 in reverse direction
    - T1@ 200,0 DT@ 50,0
- Result: One continuous edge from (0,0) to (200,0), with the overlapping region merged seamlessly

## Collinear Full-Interior-Overlap Edge Merge
- Scope: Tool & Post
- Logic: Edge Merge (full interior)
- Precondition: An existing edge E1 from (0,0) to (200,0)
- Action: Draw a second edge that overlaps the middle of E1 in reverse direction
    - T1@ 150,0 T2@ 50,0
- Result: One continuous edge from (0,0) to (200,0), with the overlapping region merged seamlessly

## Edge & Vertex Full-Interior Merge  
- Scope: Tool & Post  
- Logic: Edge Merge + Vertex Merge (full interior)  
- Precondition: An existing edge E1 from (0,0) to (100,0)  
- Action: Draw a new segment that starts outside and ends exactly on the start vertex of E1  
    - T1@ 200,0 T2@ 0,0  
- Result: One continuous edge from (0,0) to (200,0), with the entire original segment merged, and the 0,0 vertex unified  

## Edge & Vertex Half-Interior Merge  
- Scope: Tool & Post  
- Logic: Edge Merge + Vertex Merge (half interior)  
- Precondition: An existing edge E1 from (0,0) to (100,0)  
- Action: Draw a new segment that starts inside E1 and ends on its start vertex  
    - T1@ 50,0 T2@ 0,0   
- Result: One continuous edge from (0,0) to (100,0), with the overlapping half merged seamlessly, and the 0,0 vertex unified  

## Collinear Merge on T-Junction
- Scope: Tool & Post
- Logic: Edge Merge + Vertex Merge (collinear on junction)
- Precondition: An existing T-junction consisting of  
    - E1 from (0,0) to (100,0)  
    - E2 from (100,100) to (100,0)  
    - E3 from (200,0) to (100,0)  
- Action: Draw a new segment extending the horizontal line, ending on the junction vertex  
    - T1@ 300,0 DT@ 100,0  
- Result: One continuous horizontal edge from (0,0) to (300,0), with the new segment merged into the existing chain and the vertical branch at (100,0) preserved  

## Collinear Merge on T-Junction (Reverse Endpoint)
- Scope: Tool & Post
- Logic: Edge Merge + Vertex Merge (collinear on junction)
- Precondition: An existing T-junction consisting of  
    - E1 from (0,0) to (100,0)  
    - E2 from (100,100) to (100,0)  
    - E3 from (200,0) to (100,0)  
- Action: Draw a new segment extending the horizontal line, ending on the startpoint of E1 
    - T1@ 300,0 DT@ 0,0  
- Result: One continuous horizontal edge from (0,0) to (300,0), with the entire original E1 merged and both endpoints unified into the existing vertex at (0,0) and the vertical branch still attached at (100,0)  
