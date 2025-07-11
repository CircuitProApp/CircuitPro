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

## Simple Connection Drag

- Precondition: An existing Connection: 
    - E1 from (0,0) to (100,0)
- Action: Drag E1 by (100,100)
- Result: E1 from (100,100) to (200,100)
