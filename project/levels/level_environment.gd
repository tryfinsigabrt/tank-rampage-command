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


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not PlayerSettings.shadow_quality_updated.is_connected(_on_shadow_quality_updated):
		PlayerSettings.shadow_quality_updated.connect(_on_shadow_quality_updated)
	apply_shadow_quality(PlayerSettings.get_shadow_quality())


func _exit_tree() -> void:
	if PlayerSettings.shadow_quality_updated.is_connected(_on_shadow_quality_updated):
		PlayerSettings.shadow_quality_updated.disconnect(_on_shadow_quality_updated)


func apply_shadow_quality(shadow_quality: PlayerSettings.ShadowQuality) -> void:
	if directional_light == null:
		return
	
	directional_light.shadow_enabled = true
	directional_light.directional_shadow_fade_start = 0.5
	directional_light.directional_shadow_max_distance = 1000.0

	match shadow_quality:
		PlayerSettings.ShadowQuality.LOW:
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		PlayerSettings.ShadowQuality.MEDIUM:
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		PlayerSettings.ShadowQuality.HIGH:
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func _on_shadow_quality_updated(value: int) -> void:
	apply_shadow_quality(value as PlayerSettings.ShadowQuality)
