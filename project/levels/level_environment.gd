class_name LevelEnvironment extends Node3D

@onready var directional_light: DirectionalLight3D = %DirectionalLight3D

# Current min/max zoom distance levels
const ZOOM_DISTANCE_RANGE := Vector2(150.0, 1150.0)
# Max shadow distance, must be higher than zoom distance because of camera distance at the top of
# the screen is further away than the actuall zoom level
const MAX_DISTANCE_RANGE := Vector2(350.0, 1700.0)

var _rts_camera: RTSCamera
# Based on the RTS camera distance from the Y=0 plane, this is the default starting distance
var _current_zoom_distance := 550.0

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
	_connect_rts_camera_zoom()
	apply_shadow_quality(PlayerSettings.get_shadow_quality())


func _exit_tree() -> void:
	if PlayerSettings.shadow_quality_updated.is_connected(_on_shadow_quality_updated):
		PlayerSettings.shadow_quality_updated.disconnect(_on_shadow_quality_updated)
	_disconnect_rts_camera_zoom()


func apply_shadow_quality(shadow_quality: PlayerSettings.ShadowQuality) -> void:
	if directional_light == null:
		return
	
	directional_light.shadow_enabled = true
	directional_light.directional_shadow_fade_start = 0.5
	directional_light.directional_shadow_max_distance = 1000.0

	match shadow_quality:
		PlayerSettings.ShadowQuality.LOW:
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			directional_light.directional_shadow_max_distance = 700.0
		PlayerSettings.ShadowQuality.MEDIUM:
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			directional_light.directional_shadow_blend_splits = true
			_apply_zoom_shadow_tuning()
		PlayerSettings.ShadowQuality.HIGH:
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			directional_light.directional_shadow_blend_splits = true
			_apply_zoom_shadow_tuning()


func _on_shadow_quality_updated(value: int) -> void:
	apply_shadow_quality(value as PlayerSettings.ShadowQuality)


func _connect_rts_camera_zoom() -> void:
	var player := get_tree().get_first_node_in_group(Groups.Player)
	if player == null:
		return

	_rts_camera = player.get_node_or_null("RTSCamera") as RTSCamera
	if _rts_camera == null:
		return

	if not _rts_camera.zoom_level_updated.is_connected(_on_zoom_level_updated):
		_rts_camera.zoom_level_updated.connect(_on_zoom_level_updated)


func _disconnect_rts_camera_zoom() -> void:
	if _rts_camera and _rts_camera.zoom_level_updated.is_connected(_on_zoom_level_updated):
		_rts_camera.zoom_level_updated.disconnect(_on_zoom_level_updated)
	_rts_camera = null


func _on_zoom_level_updated(distance: float) -> void:
	_current_zoom_distance = distance
	_apply_zoom_shadow_tuning()


func _apply_zoom_shadow_tuning() -> void:
	if directional_light == null:
		return

	var shadow_quality := PlayerSettings.get_shadow_quality()
	var clamped_distance := clampf(_current_zoom_distance, ZOOM_DISTANCE_RANGE.x, ZOOM_DISTANCE_RANGE.y)
	directional_light.directional_shadow_max_distance = remap(
		clamped_distance,
		ZOOM_DISTANCE_RANGE.x,
		ZOOM_DISTANCE_RANGE.y,
		MAX_DISTANCE_RANGE.x,
		MAX_DISTANCE_RANGE.y
	)
	match shadow_quality:
		PlayerSettings.ShadowQuality.MEDIUM:
			directional_light.directional_shadow_split_1 = 0.5
		PlayerSettings.ShadowQuality.HIGH:
			directional_light.directional_shadow_split_1 = 0.25
			directional_light.directional_shadow_split_2 = 0.50
			directional_light.directional_shadow_split_3 = 0.75
