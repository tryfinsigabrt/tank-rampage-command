@tool
extends CommandActionLeaf

var _unit:Unit
var _target_position:Vector3 = Vector3.INF
var _finished:bool = false

func _cleanup(actor: Node, blackboard: UnitBlackboard) -> void:
	super._cleanup(actor, blackboard)
	if not _finished:
		SignalBus.on_unit_move_canceled.emit(actor as Unit, _target_position)
		_target_position = Vector3.INF
		_disconnect_move_signal()
		
func before_run(actor: Node, blackboard: Blackboard) -> void:
	super.before_run(actor, blackboard)
	_finished = false

	_unit = actor as Unit	
	if not _unit or not blackboard.has_value(UnitBlackboard.Keys.TargetPosition):
		_finished = true
		push_error("%s: Missing current unit or target position - cannot perform attack action" % name)
		return
	
	_target_position = blackboard.get_value(UnitBlackboard.Keys.TargetPosition)

	_connect_move_signal()
	SignalBus.on_unit_move_issued.emit(_unit, _target_position)
	
func tick(_actor: Node, blackboard: Blackboard) -> int:
	var result:int
	if _finished:
		result = SUCCESS
	else:
		result = _check_running_state(blackboard)
		
	return result

func _on_destination_reached(unit:Unit, target:Vector3) -> void:
	if unit != _unit:
		return
	
	if LogUtils.verbose:
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
	var current_target:Vector3 = blackboard.get_value(UnitBlackboard.Keys.TargetPosition, Vector3.INF)
	return current_target.is_equal_approx(_target_position)

func _get_action_args() -> Dictionary[StringName, Variant]:
	return {
		&"position" : _target_position
	}
