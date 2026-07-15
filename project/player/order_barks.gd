class_name OrderBarks extends Node

@export
var _order_barks:Dictionary[StringName,AudioPlayerConfig]

@export
var _selection_barks:AudioPlayerConfig

var _selection_frame:int = -1

func _ready() -> void:
	if _selection_barks:
		SignalBus.on_unit_selected.connect(_on_unit_selected)
	if _order_barks:
		SignalBus.on_order_manager_command_issued.connect(_on_order_manager_command)

func _on_order_manager_command(command:StringName) -> void:
	var player_config:AudioPlayerConfig = _order_barks.get(command)
	if player_config:
		GameManager.audio_manager.play_global(player_config)

func _on_unit_selected(unit:Unit) -> void:
	if not GameManager.is_owned_by_player(unit):
		return
		
	var curr_frame:int = GameManager.game_timer.frame
	# Don't play for each unit selected in a multi-select case
	if curr_frame == _selection_frame:
		return
	
	GameManager.audio_manager.play_global(_selection_barks)
	_selection_frame = curr_frame
