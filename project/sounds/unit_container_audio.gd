class_name UnitContainerAudio extends Node

@export
var unit_load_start_audio:AudioPlayerConfig

@export
var unit_load_complete_audio:AudioPlayerConfig

@export
var unit_unload_start_audio:AudioPlayerConfig

@export
var unit_unload_complete_audio:AudioPlayerConfig

@export
var load_complete_delay:float = 1.0

@export
var load_start_debounce:float = 0.5

@export
var unload_complete_delay:float = 1.0


var _unload_complete_timer:Timer
var _load_complete_timer:Timer
var _last_load_time:float

func _ready() -> void:
	var unit_container := _find_unit_container_component()
	assert(unit_container)
	if not unit_container:
		queue_free()
		return
		
	_bind_signals(unit_container)
	
	_last_load_time = -load_start_debounce
	
func _find_unit_container_component() -> UnitContainerComponent:
	var team_asset:Node = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if not team_asset:
		push_error("%s: UnitContainerAudio not added to a team asset scene tree" % name)
		return null
	return UnitContainerComponent.get_component(team_asset)
	

func _bind_signals(unit_container:UnitContainerComponent) -> void:
	## Opportunity to calculate desired position of units and set them prior to the removal
	if unit_unload_start_audio or unit_unload_complete_audio:
		unit_container.on_unit_removal_requested.connect(_on_unload_start.bind(unit_container))
		if unit_unload_complete_audio:
			_unload_complete_timer = _create_and_add_timer("UnloadCompleteTimer", unload_complete_delay, _on_unload_complete)
			
	if unit_load_start_audio or unit_load_complete_audio:
		unit_container.on_unit_added.connect(_on_load_start.bind(unit_container))
		if unit_load_complete_audio:
			_load_complete_timer = _create_and_add_timer("LoadCompleteTimer", load_complete_delay, _on_load_complete)

func _create_and_add_timer(in_name:StringName, time:float, callback:Callable) -> Timer:
	var timer:Timer = Timer.new()
	
	timer.name = in_name
	timer.autostart = false
	timer.one_shot = true
	timer.wait_time = time
	timer.timeout.connect(callback)
	
	add_child(timer)
	
	return timer
	
func _on_unload_start(_units:Array[Unit], _container:UnitContainerComponent) -> void:
	if unit_unload_start_audio:
		GameManager.audio_manager.play_global(unit_unload_start_audio)
	
	if _unload_complete_timer:
		_unload_complete_timer.start()
	if _load_complete_timer:
		_load_complete_timer.stop()

func _on_load_start(_unit:Unit, container:UnitContainerComponent) -> void:
	if unit_load_start_audio:
		var time:float = GameManager.game_timer.time_seconds
		var dt:float = time - _last_load_time
		if dt >= load_start_debounce:
			GameManager.audio_manager.play_global(unit_load_start_audio)
			_last_load_time = time
	
	if _unload_complete_timer:
		_unload_complete_timer.stop()
	
	if container.is_full and _load_complete_timer:
		_load_complete_timer.start()
	
func _on_unload_complete() -> void:
	GameManager.audio_manager.play_global(unit_unload_complete_audio)

func _on_load_complete() -> void:
	GameManager.audio_manager.play_global(unit_load_complete_audio)
