## Sfx designed to be attached directly to an asset and play when health decreases
## Some Sfx such as those on vehicle hits are emitted from the weapon but others like marines are independent of weapon
## and should be played on the asset themselves
class_name HitSfx extends Node3D

@export
var audio_player_config:AudioPlayerConfig

## Time to wait before replaying the sound again on another hit
@export
var replay_backoff_time:float = 0.0

## Indicate whether a damage event that results in death should cause the sound to still play
## Usually want this as false if have a separate sound effect for death.
@export
var play_on_death:bool = false

var _last_play_time:float = -1.0

func _ready() -> void:
	assert(audio_player_config)
	if not audio_player_config:
		queue_free()
		return
		
	var team_asset:Node = Groups.get_parent_in_group(self, Groups.TeamAsset)
	assert(team_asset)
	if not team_asset:
		queue_free()
		return
	
	var health_stat:HealthStat = HealthStat.get_component(team_asset, true)
	if not health_stat:
		push_error("%s: HealthStat is required on %s for hit sfx to play!" % [name, team_asset.name])
		queue_free()
		return
		
	health_stat.health_changed.connect(_on_health_changed)

func _on_health_changed(previous_health:float, current_health:float) -> void:
	if current_health >= previous_health:
		return
	if is_zero_approx(current_health) and not play_on_death:
		return
	if not _check_if_playable():
		return
			
	GameManager.audio_manager.play_3d(audio_player_config, global_position)

func _get_time() -> float:
	return Time.get_ticks_usec() / 1.0e6 if audio_player_config.play_when_paused else GameManager.game_timer.time_seconds

func _check_if_playable() -> bool:
	if replay_backoff_time <= 0.0:
		return true
	var curr_time:float = _get_time()
	
	var can_play:bool
	if _last_play_time >= 0.0:
		can_play = curr_time - _last_play_time >= replay_backoff_time
	else:
		can_play = true
	
	if can_play:
		_last_play_time = curr_time
		
	return can_play
