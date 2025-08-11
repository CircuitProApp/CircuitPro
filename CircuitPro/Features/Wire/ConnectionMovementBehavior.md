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

### Test 1 
- Action: Drag E1 by -100 across X 
- Result: E1 moves freely while E2 stretches with its endpoint (100,0) is anchored 

### Test 2
- Action: Drag E1 by 200 across X 
- Result: E1 moves freely while E2 shrinks with its endpoint (100,0) is anchored, we receive the mirrored shape of the original L

### Test 3 Merge
- Action: Drag E1 by 100 across X
- Result: E1 moves freely and while E2 collapses with only E1 left

*Addendum: Applies to the most of shapes like C-Shapes, G-shapes, O-Shape etc.*

## G-Shape Cases

- Precondition: An existing G-Shape Connection:
    - E1 from (100,100) to (0,100)
    - E2 from (0,100) to (0,0)
    - E3 from (0,0) to (200,0)
    - E4 from (200,0) to (200,100)

### Test 1
- Action: Drag E2 across X by 100
- Result: Collapsed E1 with remaining E2, E3, E4 Edges

### Test 2
- Action: Drag E2 across X by 200
- Result: Merge E2, E3 and E4 into a new Edge still connected to E1, forming an L-Shape

### Test 3 (T-Junction Creation)
- Action: Drag E2 across X by 300
- Result: E1 from (100,100) to (300,100) split by E4 in half at 200,100
    
## P-Shape Case

- Precondition: An existing P-Shape Connection:
    - E1 from (0,200) to (0,100)
    - E2 from (0,100) to (0,0)
    - E3 from (0,0) to (100,0)
    - E4 from (100,0) to (100,100)
    - E5 from (100,100) to (0,100)

### Test 1
- Action: Drag E1 along X by 50
- Result: E1 (50,200) to (50,100) moving the junction from the ledge to the (50,100), splitting E5 in two

### Test 2
- Action: Drag E1 along X by -50
- Result: E1 (-50,200) to (-50,100) creating a new orthogonal Edge from (-50,100) to (0,100)

### Test 3
- Action: Drag E1 along Y by -50
- Result Half of E1 gets merged into E2, new E1 (0,150) to (0,100)

### Test 4
- Action: Drag E1 along Y by 50
- Result E1 elongates, E1 becomes (0,250) to (0,100)


## T-Shape Edge Drag

- Precondition: An existing T-Shape Connection:
    - E1 from (0,100) to (0,0)
    - E2 from (0,0) to (100,0)
    - E3 from (0,0) to (0,-100)
- Action: Drag E1 by -100 across X 
- Result: E1 moves freely while there's a new edge created E4 from (-100,0) to (0,0)
