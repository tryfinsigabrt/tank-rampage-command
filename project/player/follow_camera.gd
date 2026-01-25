class_name FollowCamera extends Node3D

@export
var follow_unit:Unit

@onready var camera: Camera3D = %Camera

var _initial_offset:Vector3
		
func make_camera_current() -> void:
	camera.make_current()
	
func _ready() -> void:
	_initial_offset = camera.position

func _process(_delta: float) -> void:
	if is_instance_valid(follow_unit):
		camera.global_position = follow_unit.global_position + _initial_offset
