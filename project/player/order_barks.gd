class_name OrderBarks extends Node

@export
var _order_barks:Dictionary[StringName,AudioStreamPlayer]

@export
var _selection_barks:AudioStreamPlayer

var _selection_frame:int = -1

func _ready() -> void:
	if _selection_barks:
		SignalBus.on_unit_selected.connect(_on_unit_selected.unbind(1))
	if _order_barks:
		SignalBus.on_order_manager_command_issued.connect(_on_order_manager_command)

func _on_order_manager_command(command:StringName) -> void:
	var player:AudioStreamPlayer = _order_barks.get(command)
	if player:
		player.play()

func _on_unit_selected() -> void:
	var curr_frame:int = GameManager.game_timer.frame
	# Don't play for each unit selected in a multi-select case
	if curr_frame == _selection_frame:
		return
	
	_selection_barks.play()
	_selection_frame = curr_frame
