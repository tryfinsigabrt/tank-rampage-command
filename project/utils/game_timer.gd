class_name GameTimer extends Node

@export
var set_shader_game_time:bool

var _time_seconds:float = 0.0  # Elapsed game time in seconds
var _frame_count:int = 0
var _source:Timer

func _init() -> void:
	process_mode = ProcessMode.PROCESS_MODE_PAUSABLE

func set_source(timer:Timer) -> void:
	_source = timer
	
func reset() -> void:
	_time_seconds = 0.0
	_frame_count = 0
	_source = null

func set_enabled(enabled:bool) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE if enabled else Node.PROCESS_MODE_DISABLED
		
var time_seconds: float:
	get:
		return _time_seconds if not is_instance_valid(_source) else _source.wait_time - _source.time_left

var time_ms: float:
	get:
		return time_seconds * 1000

var frame:int:
	get: return _frame_count
	
func _process(delta: float) -> void:
	_time_seconds += delta
	_frame_count += 1
	
	if set_shader_game_time:
		RenderingServer.global_shader_parameter_set(&"game_time", _time_seconds)
