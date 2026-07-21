extends Node3D

@export_range(0.0, 100.0, 0.01, "or_greater")
var caster_height: float = 2.5

@export_range(-10.0, 10.0, 0.01)
var ground_offset_y: float = 0.05


func _process(_delta: float) -> void:
	var parent_node := get_parent_node_3d()
	if parent_node == null:
		return

	var level_environment := get_tree().get_first_node_in_group("LevelEnvironment") as LevelEnvironment
	if level_environment == null:
		return

	var light_direction := level_environment.get_directional_light_direction()
	var light_y := absf(light_direction.y)
	if light_y <= 0.001:
		return

	var caster_position := parent_node.global_position
	var horizontal_offset := Vector3(light_direction.x, 0.0, light_direction.z) * (caster_height / light_y)
	var target_global_position := Vector3(
		caster_position.x + horizontal_offset.x,
		ground_offset_y,
		caster_position.z + horizontal_offset.z
	)

	position = parent_node.to_local(target_global_position)
