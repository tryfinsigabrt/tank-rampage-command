class_name AudioPlayerPool3D extends AudioPlayerPool
	
const INT_MAX:int = 0x7fffffffffffffff

var _players:Array[AudioStreamPlayer3D]
var _start_times:PackedInt64Array

var _attached_players:Array[AttachedAudio]

class AttachedAudio:
	var player:AudioStreamPlayer3D
	var followed:Node3D
	
	func _init(in_player:AudioStreamPlayer3D, in_followed:Node3D) -> void:
		self.player = in_player
		self.followed = in_followed
		
	func update() -> bool:
		if not player.playing or not is_instance_valid(followed):
			return false
		
		player.global_transform = followed.global_transform
		
		return true
		
func _ready() -> void:
	assert(config)
		
	var pool_size: int = config.max_concurrency
	var size_digits:int = MathUtils.num_int_digits(pool_size)
	var name_formatter:String = "Player%%0%dd" % size_digits
	for i in pool_size:
		var player := AudioStreamPlayer3D.new()
		player.name = name_formatter % i
		
		add_child(player)
		_players.push_back(player)
	_start_times.resize(pool_size)
	
	set_process(false)

func _process(_delta: float) -> void:
	for i in range(_attached_players.size() - 1, -1, -1):
		var entry := _attached_players[i]
		if not entry.update():
			_attached_players.remove_at(i)
	
	if not _attached_players:
		set_process(false)
		
func play(player_config:AudioPlayerConfig, position:Vector3) -> void:
	if not player_config or not player_config.valid:
		return
	
	var player := _get_available_player()
	_play_with_config(player, player_config, position)
	
func play_attached(player_config:AudioPlayerConfig, node:Node3D) -> void:
	if not player_config or not player_config.valid:
		return
	
	var player := _get_available_player()
	_play_with_config(player, player_config, node.global_position)
	
	# Add tracking
	_attached_players.push_back(AttachedAudio.new(player, node))
	set_process(true)
	
func _play_with_config(player:AudioStreamPlayer3D, player_config:AudioPlayerConfig, position:Vector3) -> void:
	var stream_config := player_config.stream_config
	
	player.bus = player_config.bus
	player.attenuation_model = player_config.attenuation_model
	player.max_distance = player_config.max_distance
	player.pitch_scale = player_config.pitch_scale
	player.unit_size = player_config.unit_size
	player.volume_db = player_config.volume_db
	player.max_db = player_config.volume_max_db
	player.stream = stream_config.stream
	player.global_position = position
	
	player.play(stream_config.play_from)
	
func _get_available_player() -> AudioStreamPlayer3D:
	# First, look for any player that is completely idle
	var curr_time:int = Time.get_ticks_usec()
	var player:AudioStreamPlayer3D
	
	for i in _players.size():
		player = _players[i]
		if not player.playing:
			_start_times[i] = curr_time
			if OS.is_debug_build():
				print_debug("%s: Playing from idle with %s" % [name, player.name])
			return player
			
	# If all players are busy, steal the oldest playing one 
	var min_index:int = -1
	var min_time:int = INT_MAX
	for i in _start_times.size():
		var time := _start_times[i]
		if time < min_time:
			min_index = i
			min_time = time
					
	_start_times[min_index] = curr_time
	player = _players[min_index]
	
	if OS.is_debug_build():
		print_debug("%s: Playing using oldest %s started %.3f ms ago" % [name, player.name, (curr_time - min_time) / 1000.0])
		
	player.stop()
	
	return player
