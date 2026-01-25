class_name Turret extends Node3D

@export_range(0.0,1e9, 0.01, "or_greater")
var angular_speed_deg:float = 90.0

func rotate_turret(direction:float) -> void:
	if is_zero_approx(direction):
		return
	var rot:float = angular_speed_deg * get_process_delta_time() * signf(direction)
	rotation_degrees += Vector3.UP * rot
