class_name LevelEnvironment extends Node3D

@onready var directional_light: DirectionalLight3D = %DirectionalLight3D


func get_directional_light() -> DirectionalLight3D:
	return directional_light


func get_directional_light_direction() -> Vector3:
	if directional_light == null:
		return Vector3.DOWN

	# Directional lights shine along their negative forward axis.
	return -directional_light.global_basis.z.normalized()


func get_ground_shadow_direction() -> Vector3:
	var light_direction := get_directional_light_direction()
	return Vector3(light_direction.x, 0.0, light_direction.z).normalized()
