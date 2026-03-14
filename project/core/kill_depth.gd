class_name KillDepth extends Area3D

@onready var shape: CollisionShape3D = $Shape

@export
var kill_depth:float = -1000.0

const PLANE_SIZE:float = 1_000_000
const DEPTH_SIZE:float = 100.0

func _ready() -> void:
	global_position.y = kill_depth * 0.5
	var box: BoxShape3D = shape.shape
	
	box.size = Vector3(PLANE_SIZE, DEPTH_SIZE, PLANE_SIZE)
	shape.position.y = -0.5 * DEPTH_SIZE
	
func _on_body_entered(body: Node3D) -> void:
	var unit:Unit = body as Unit
	if not unit:
		return
		
	push_warning("%s: Unit %s entered kill depth" % [name, unit.name])
	unit.kill()
