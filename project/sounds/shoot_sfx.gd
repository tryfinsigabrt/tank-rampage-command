## Plays the shoot sound, delegating to the appropriate AudioStreamPlayer
class_name ShootSfx extends Node3D

@onready var audio_stream_switcher: AudioStreamSwitcher = $AudioStreamSwitcher

@export
var hit_streams_by_group:Dictionary[StringName,AudioStreamConfig]

@export
var explosion_streams_by_grid_distance:Array[AudioStreamDistanceConfig]

@export
var shoot_audio:AudioPlayerConfig

@export
var hit_audio:AudioPlayerConfig

@export
var explosion_audio:AudioPlayerConfig

func play_shoot() -> void:
	if shoot_audio:
		GameManager.audio_manager.play_3d(shoot_audio, global_position)

func play_hit(damage_params:DamageParameters) -> void:
	var location:Vector3 = damage_params.contact_point
	
	if hit_audio:
		audio_stream_switcher.play_stream(hit_audio, location, _select_hit_stream(damage_params))
	if explosion_audio:
		audio_stream_switcher.play_stream(explosion_audio, location, _select_explosion_stream(damage_params))

func _select_hit_stream(damage_params:DamageParameters) -> AudioStreamConfig:
	var target:Node3D = damage_params.target_object
	# A node typically has more groups than we have hit stream customizations so opt to loop through the keys rather than the groups
	var node_groups := target.get_groups()
	if not node_groups:
		return null
	for group in hit_streams_by_group:
		if group in node_groups:
			return hit_streams_by_group[group]
	return null

func _select_explosion_stream(damage_params:DamageParameters) -> AudioStreamConfig:
	return audio_stream_switcher.select_stream_by_camera_distance(explosion_streams_by_grid_distance, damage_params.contact_point)
