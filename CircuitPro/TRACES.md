# Trace Drag Behavior

## 1

Initial:

E1: 0,0 -> 0,100
E2: 0,100 -> 100,200

Action:

Drag E2 bottom by 150 (y-150)

Expected:

E1: 0,0 -> 50,0
E2: 50,0 -> 100,50

## 2

Initial:

E1: 0,0 -> 50,0
E2: 50,0 -> 100,50

Action:

Drag E2 bottom by 100 (y-100)

Expected:

E1: 0,0 -> 50,0
E2: 50,0 -> 100,-50

## 3

Initial:

E1: 0,0 -> 0,100
E2: 0,100 -> 100,200

Action:

Drag E2 left by 200 (x-200)

Expected:

E1: 0,0 -> 0,100
E2: 0,100 -> -100,200
