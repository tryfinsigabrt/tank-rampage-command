class_name TankBody extends Node3D

@export_range(0.0, 1e9, 0.1, "or_greater")
var turning_speed_degrees:float = 90.0

func turn(direction:float) -> void:
	if is_zero_approx(direction):
		return
	var rot:float = turning_speed_degrees * get_physics_process_delta_time() * signf(direction)
	rotation_degrees += Vector3.UP * rot
