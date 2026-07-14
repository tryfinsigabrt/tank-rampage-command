class_name MusicManager extends Node

@onready var _game_config_holder: GameConfigHolder = %GameConfigHolder
@onready var _audio_manager: AudioManager = %AudioManager

var _audio_by_level_resource:Dictionary[String, AudioPlayerConfig]
var _main_menu_music_player:AudioPlayerConfig

func _ready() -> void:
	var game_config:GameConfig = _game_config_holder.game_config
	assert(game_config)
	if not game_config:
		push_error("%s: No game config configured - music will not play!" % name)
		queue_free()
		return
	
	_main_menu_music_player = game_config.menu_music_player
	_add_mapping_for_level_config(game_config.tutorial_level)
	
	for level in game_config.levels:
		_add_mapping_for_level_config(level)

func start_menu_music() -> void:
	_audio_manager.play_global(_main_menu_music_player)
		
func _add_mapping_for_level_config(level_config:LevelConfig) -> void:
	if level_config and level_config.level_resource:
		_audio_by_level_resource[level_config.level_resource] = level_config.music_player_resource
		
func _on_scene_change_requested(new_scene_resource: String) -> void:
	# No mapping - use main menu theme
	if new_scene_resource not in _audio_by_level_resource:
		start_menu_music()
	else:
		var player: AudioPlayerConfig = _audio_by_level_resource.get(new_scene_resource)
		# If the music is explicitly mapped to null then stop all existing playing music to avoid the main menu theme playing unexpectedly
		if player:
			_audio_manager.play_global(player)
		else:
			_audio_manager.stop_all_global_matching("Music")
		
