## Plays the shoot sound, delegating to the appropriate AudioStreamPlayer
class_name ShootSfx extends Node3D

# TODO: Replace with a pooled audio manager autoload
@onready var shoot_sfx: AudioStreamPlayer3D = $ShootSfx
@onready var hit_sfx: AudioStreamPlayer3D = $HitSfx
@onready var explosion_sfx: AudioStreamPlayer3D = $ExplosionSfx
@onready var audio_stream_switcher: AudioStreamSwitcher = $AudioStreamSwitcher

@export
var hit_streams_by_group:Dictionary[StringName,AudioStreamConfig]

@export
var explosion_streams_by_grid_distance:Array[AudioStreamDistanceConfig]

func play_shoot() -> void:
	shoot_sfx.play()

func play_hit(damage_params:DamageParameters) -> void:
	var location:Vector3 = damage_params.contact_point
	
	audio_stream_switcher.play_stream(hit_sfx, location, _select_hit_stream(damage_params))
	audio_stream_switcher.play_level_stream(explosion_sfx, location, _select_explosion_stream(damage_params))

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
