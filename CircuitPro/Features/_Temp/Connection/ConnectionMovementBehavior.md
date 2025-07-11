# Legend:

Connection - High level concept containing either a single Segment or multiple Segments within a ConnectionGraph  
Segment - Edge with two endpoints V1 and V2  
Junction - Meeting point of multiple Segments (>2)  

En - Edge n (1, 2, 3, 4, …)  
Vn - Vertex n (1, 2, 3, 4, …)  

SEL(E) - Selected Edge  

Scope - 

## Preface:

ConnectionElement is the highest level Connection representation that holds ConnectionGraph, a lower level graph management system that contains most of the code related to iner-graph modifications.

# Tests:

## Simple Edge Drag

- Precondition: An existing Connection: 
    - E1 from (0,0) to (100,0)
- Action: Drag E1 by (100,100)
- Result: E1 from (100,100) to (200,100)

## L-Shape Edge Drag

- Precondition: An existing L-Shape Connection:
    - E1 from (0,100) to (0,0)
    - E2 from (0,0) to (100,0)
- Action: Drag E1 
- Result: E1 (vertical) can only move separately freely along X axis since it's constrained by E2, However you can still move E1 along Y axis, it will move the whole E2
*Addendum: Applies to the most of shapes like C-Shapes, G-shapes, O-Shape etc.*

## G-Shape Edge Collapse

- Precondition: An existing G-Shape Connection:
    - E1 from (100,100) to (0,100)
    - E2 from (0,100) to (0,0)
    - E3 from (0,0) to (200,0)
    - E4 from (200,0) to (200,100)
- Action: Drag E2 across X axis by 100
- Result: Collapsed E1 with remaining E2, E3, E4 Edges
    
## G-Shape Close Loop

- Precondition: An existing G-Shape Connection:
    - E1 from (100,100) to (0,100)
    - E2 from (0,100) to (0,0)
    - E3 from (0,0) to (200,0)
    - E4 from (200,0) to (200,100)
- Action: Drag E4 across X axis by -100
- Result: Closed loop consisting of E1, E2, E3 and E4
