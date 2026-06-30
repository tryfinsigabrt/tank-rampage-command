class_name AudioPlayerPoolGlobal extends AudioPlayerPool
	
const INT_MAX:int = 0x7fffffffffffffff

var _players:Array[AudioStreamPlayer]
var _start_times:PackedInt64Array
		
func _ready() -> void:
	assert(config)
		
	var pool_size: int = config.max_concurrency
	var size_digits:int = MathUtils.num_int_digits(pool_size)
	var name_formatter:String = "Player%%0%dd" % size_digits
	
	for i in pool_size:
		var player := AudioStreamPlayer.new()
		player.name = name_formatter % i
		
		add_child(player)
		_players.push_back(player)
	_start_times.resize(pool_size)
		
func play(player_config:AudioPlayerConfig) -> void:
	if not player_config or not player_config.valid:
		return
	
	var player := _get_available_player()
	_play_with_config(player, player_config)

func _play_with_config(player:AudioStreamPlayer, player_config:AudioPlayerConfig) -> void:
	var stream_config := player_config.stream_config
	
	player.bus = player_config.bus
	player.attenuation_model = player_config.attenuation_model
	player.max_distance = player_config.max_distance
	player.pitch_scale = player_config.pitch_scale
	player.unit_size = player_config.unit_size
	player.volume_db = player_config.volume_db
	player.max_db = player_config.volume_max_db
	player.stream = stream_config.stream
	
	player.play(stream_config.play_from)
	
func _get_available_player() -> AudioStreamPlayer:
	# First, look for any player that is completely idle
	var curr_time:int = Time.get_ticks_usec()
	var player:AudioStreamPlayer
	
	for i in _players.size():
		player = _players[i]
		if not player.playing:
			_start_times[i] = curr_time
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
	player.stop()
	
	return player
