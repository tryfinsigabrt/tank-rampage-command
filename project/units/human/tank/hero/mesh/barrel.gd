class_name TankBarrel extends Node3D

@onready var pivot: Marker3D = $Pivot
@onready var fire_location: Marker3D = %FireLocation

@export_range(0.0, 90.0, 0.01)
var max_pitch_degrees:float = 30.0

@export_range(0.0, 90.0, 0.01)
var rotation_speed_degrees:float = 15.0

func pitch_barrel(direction:float) -> void:
	if is_zero_approx(direction):
		return
	var rot:float = rotation_speed_degrees * get_physics_process_delta_time() * signf(direction)
	pivot.rotation_degrees.x = clampf(pivot.rotation_degrees.x + rot, -max_pitch_degrees, 0.0)
