class_name GroundActionIndicator extends Node3D

@export
var material:Material

@export
var lifetime:float = 3.0

@onready var mesh: MeshInstance3D = %Mesh
@onready var display_timer: Timer = %DisplayTimer

func _ready() -> void:
	mesh.material_override = material
	hide()
	
	if lifetime > 0:
		display_timer.wait_time = lifetime
		display_timer.timeout.connect(hide)
		

func display_at(pos:Vector3) -> void:
	global_position = pos
	show()
	
	if lifetime > 0:
		display_timer.start()
