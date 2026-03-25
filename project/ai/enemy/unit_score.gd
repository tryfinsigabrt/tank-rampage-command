class_name UnitScore

var threat:Node3D
var priority:int
var score:float

var _dist_sq:float
var dist:float = -1.0:
	get:
		if dist < 0.0:
			dist = sqrt(_dist_sq)
		return dist
	
