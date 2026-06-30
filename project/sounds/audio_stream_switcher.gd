class_name AudioStreamSwitcher extends Node

func select_stream_by_camera_distance(streams:Array[AudioStreamDistanceConfig], world_location:Vector3) -> AudioStreamConfig:
	if not streams:
		return null
		
	var viewport:Viewport = get_viewport()
	if not viewport:
		return null
	var active_camera:Camera3D = viewport.get_camera_3d()
	if not active_camera:
		return null
		
	var to_camera:Vector2 = MathUtils.grid_vector(active_camera.global_position - world_location)
	var dist:float = to_camera.length()
	for config in streams:
		if config.max_distance <= dist:
			return config
	return null

func play_stream(player_config:AudioPlayerConfig, world_location:Vector3, stream_override:AudioStreamConfig = null) -> void:
	if not player_config:
		return
		
	if stream_override:
		# Avoid changing global config since resources are shared across the game
		player_config = player_config.duplicate()
		player_config.stream_config = stream_override
		
	GameManager.audio_manager.play_3d(player_config, world_location)
