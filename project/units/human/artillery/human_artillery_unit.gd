class_name HumanArtilleryUnit extends Unit


## Provides the screen direction to instruct the unit to move to
func move(input_direction:Vector2, speed_override:float = -1.0) -> void:
	pass


func aim_at(world_location:Vector3) -> void:
	pass

func shoot() -> void:
	pass

func _is_moving() -> bool:
	return false

func _update_render() -> void:
	pass
