extends Node3D

@onready var audio_stream_switcher: AudioStreamSwitcher = $AudioStreamSwitcher

@export
var audio_player_config:AudioPlayerConfig

@export
var streams_by_distance:Array[AudioStreamDistanceConfig]

func _ready() -> void:
	if not audio_player_config:
		return
		
	var team_asset:Node = Groups.get_parent_in_group(self, Groups.TeamAsset)
	assert(team_asset)
	if not team_asset:
		queue_free()
		return
	
	HealthStat.connect_died_signal(team_asset, _on_asset_died)

func _on_asset_died() -> void:
	var stream_config:AudioStreamConfig = audio_stream_switcher.select_stream_by_camera_distance(streams_by_distance, global_position)
	if stream_config:
		audio_player_config = audio_player_config.duplicate()
		audio_player_config.stream_config = stream_config
			
	GameManager.audio_manager.play_3d(audio_player_config, global_position)
