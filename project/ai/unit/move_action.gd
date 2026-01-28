@tool
extends ActionLeaf

var _unit:Unit
var _finished:bool = false

func interrupt(actor: Node, blackboard: Blackboard) -> void:
	SignalBus.on_unit_move_canceled.emit(actor as Unit, blackboard.get_value(UnitBlackboard.Keys.TargetPosition))
	_disconnect_move_signal()
	super.interrupt(actor, blackboard)
	
func before_run(actor: Node, blackboard: Blackboard) -> void:
	_unit = actor as Unit
	var target_position:Vector3 = blackboard.get_value(UnitBlackboard.Keys.TargetPosition)
	
	_connect_move_signal()
	SignalBus.on_unit_move_issued.emit(_unit, target_position)
	
func tick(_actor: Node, _blackboard: Blackboard) -> int:
	return SUCCESS if _finished else RUNNING

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
