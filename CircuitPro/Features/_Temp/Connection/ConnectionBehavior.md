#Legend:

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

##Preface:
ConnectionElement is the highest level Connection representation that holds ConnectionGraph, a lower level graph management system that contains most of the code related to iner-graph modifications.

The connection behavior code is delegated through two stages, one within ConnectionTool scope and one in CanvasInteractionController and CoreGraphicsCanvasView.

#Tests:

##Simple Connection Creation
- Scope: Tool
- Result: A single connection edge
    - T@ 0,0 DT@ 100,0

##L-shape Connection Creation
- Scope: Tool
- Result: Two orthogonal edges joined by one vertex at endpoints. S1 0,0 100,0 S2 100,0 100,100
    - T@ 0,0 DT@ 100,100

##Closed Connection Creation
- Scope: Tool
- Logic: Vertex Merging
- Result: A single close looped connection where the first edge’s start vertex and last edge’s endpoint vertex are the same
    - T1@ 0,0 T2@ 100,0 T3@ 100,100 T4@ 0,100 T5@ 0,0

##Closed Connection Creation, L-shape variant
- Scope: Tool
- Logic: Vertex Merging
- Result: A single close looped connection where the first edge’s start vertex and last edge’s endpoint vertex are the same
    - T1@ 0,0 T2@ 100,100 T3@ 0,0
    
##Closed Connection Dismantling
- Scope: Post
- Result: A C-shaped whole connection
- Precondition: A closed-loop Connection 0,0 100,0 100,100 0,100
    - SEL(E3 [100,0 100,100]) BKSP

##Closed Connection Self-Intersection Creation
- Scope: Tool
- Logic: Edge Split
- Result: A connection that creates a T junction with itself at 50,0
    - T1@ 0,0 T2@ 100,0 T3@ 100,100 T4@ 50,100 T5@ 50,0

##Collinear Edge Merge
- Scope: Tool
- Logic: Edge Merge
- Result: A uniform edge
    - T1@ 0,0 T2@ 100,0 DT@ 200,0

##Collinear Edge Merge Multi (>2)
- Scope: Tool
- Logic: Edge Merge
- Result: A uniform edge
    - T1@ 0,0 T2@ 100,0 T3@ 200,0  DT@ 300,0

##Orthogonal Connection Graph Merge
- Scope: Tool & Post
- Logic: Connection Merge
- Result: One uniform connection with edges that share a vertex at 100,0
- Precondition: Existing Edge from a separate tool call E1 0,0 100,0
    - T1@ 100,100 T2@ 100,0

##T-Junction Creation
- Scope: Tool & Post
- Logic: Edge Split
- Result: One uniform connection with a T shape junction where three edges share one vertex
- Precondition: Existing Edge from a separate tool call E1 0,0 100,0
    - T1@ 50,100 DT@ 50,0
    
##T-Junction Dismantling
- Scope: Post
- Logic: Edge Merge
- Precondition: Existing T-Junction E1 0,0 100,0 E2 100,100 100,0 E3 200,0 100,0
###Test 1 Result: An L-shaped connection
    - SEL(E1) BKSP
###Test 2 Result: A complete edge
    - SEL(E2) BKSP
- Addendum: In case either Edge connected with others, upon deletion resulting Connections should not exceed 2

 
