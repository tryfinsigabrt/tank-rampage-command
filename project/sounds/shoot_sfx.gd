## Plays the shoot sound, delegating to the appropriate AudioStreamPlayer
class_name ShootSfx extends Node3D

# TODO: Replace with a pooled audio manager autoload
@onready var shoot_sfx: AudioStreamPlayer3D = $ShootSfx
@onready var hit_sfx: AudioStreamPlayer3D = $HitSfx
@onready var explosion_sfx: AudioStreamPlayer3D = $ExplosionSfx

@export
var hit_streams_by_group:Dictionary[StringName,AudioStreamConfig]

func play_shoot() -> void:
	shoot_sfx.play()

func play_hit(damage_params:DamageParameters) -> void:
	_play_stream(hit_sfx, damage_params, _select_hit_stream(damage_params))
	_play_stream(explosion_sfx, damage_params)	

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
	
func _play_stream(player:AudioStreamPlayer3D, damage_params:DamageParameters, stream_override:AudioStreamConfig = null) -> void:
	var play_from:float = 0.0
	if stream_override:
		player.stream = stream_override.stream
		play_from = stream_override.play_from
	if not player.stream:
		return
		
	player.global_position = damage_params.contact_point
	player.play(play_from)
