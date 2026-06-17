extends Node3D

# TODO: Replace with a pooled audio manager autoload
@onready var player: AudioStreamPlayer3D = $Player
@onready var audio_stream_switcher: AudioStreamSwitcher = $AudioStreamSwitcher

@export
var default_stream:AudioStream

@export
var streams_by_distance:Array[AudioStreamDistanceConfig]

func _ready() -> void:
	var team_asset:Node = Groups.get_parent_in_group(self, Groups.TeamAsset)
	assert(team_asset)
	if not team_asset:
		queue_free()
		return
	
	HealthStat.connect_died_signal(team_asset, _on_asset_died)

func _on_asset_died() -> void:
	var stream_config:AudioStreamConfig = audio_stream_switcher.select_stream_by_camera_distance(streams_by_distance, global_position)
	if stream_config:
		player.stream = stream_config.stream
	elif default_stream:
		player.stream = default_stream
			
	if player.stream:
		GameManager.audio_manager.play_level_sound(player)
