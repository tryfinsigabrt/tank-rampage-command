@tool
extends CommandActionLeaf

var _unit:Unit
var _target_position:Vector3
var _finished:bool = false

func after_run(actor: Node, blackboard: Blackboard) -> void:
	if not _finished:
		SignalBus.on_unit_move_canceled.emit(actor as Unit, blackboard.get_value(UnitBlackboard.Keys.TargetPosition))
		_disconnect_move_signal()
		
func before_run(actor: Node, blackboard: Blackboard) -> void:
	super.before_run(actor, blackboard)
	_finished = false

	_unit = actor as Unit
	_target_position = blackboard.get_value(UnitBlackboard.Keys.TargetPosition)
	
	_connect_move_signal()
	SignalBus.on_unit_move_issued.emit(_unit, _target_position)
	
func tick(_actor: Node, blackboard: Blackboard) -> int:
	return SUCCESS if _finished else _check_running_state(blackboard)

func _on_destination_reached(unit:Unit, target:Vector3) -> void:
	if unit != _unit:
		return
	
	print_debug("%s: Move destination reached: %s -> %s" % [name, unit, target])
	_disconnect_move_signal()
	_finished = true

func _connect_move_signal() -> void:
	if not SignalBus.on_destination_reached.is_connected(_on_destination_reached):
		SignalBus.on_destination_reached.connect(_on_destination_reached)

func _disconnect_move_signal() -> void:
	if SignalBus.on_destination_reached.is_connected(_on_destination_reached):
		SignalBus.on_destination_reached.disconnect(_on_destination_reached)

func _should_continue_running(blackboard: Blackboard) -> bool:
	var current_target:Vector3 = blackboard.get_value(UnitBlackboard.Keys.TargetPosition)
	return current_target.is_equal_approx(_target_position)
