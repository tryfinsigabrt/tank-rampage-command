@tool
extends ActionLeaf

var _command_id:int
var _running:bool

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	return RUNNING if _running else SUCCESS
	
func before_run(actor: Node, _blackboard: Blackboard) -> void:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
	
	var position:Vector3 = blackboard.position
	
	var unit_actions:UnitActions = unit.get_or_add_actions()
	unit_actions.move_and_attack(position)
	
	_command_id = unit_actions.last_command_id
	directive.notify_command(_command_id)
	_running = true

	SignalUtils.connect_with_predicated_disconnect(unit_actions.command_finished,
		func(command_id:int, destroy:Signal) -> void:
			if command_id == _command_id:
				_running = false
				destroy.emit()
	, str(_command_id))
