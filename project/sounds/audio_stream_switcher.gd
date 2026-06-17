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
	
func play_stream(player:AudioStreamPlayer3D, world_location:Vector3, stream_override:AudioStreamConfig = null) -> void:
	var play_from:float = 0.0
	if stream_override:
		player.stream = stream_override.stream
		play_from = stream_override.play_from
	if not player.stream:
		return
		
	player.global_position = world_location
	player.play(play_from)

func play_level_stream(player:AudioStreamPlayer3D, world_location:Vector3, stream_override:AudioStreamConfig = null) -> void:
	if stream_override:
		player.stream = stream_override.stream
	if not player.stream:
		return
	
	player.global_position = world_location
	GameManager.audio_manager.play_level_sound(player)
