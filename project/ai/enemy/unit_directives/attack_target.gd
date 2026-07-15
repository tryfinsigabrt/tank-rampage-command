@tool
extends ActionLeaf

var _state:int

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	match _state:
		0: return RUNNING
		1: return SUCCESS
		_: return FAILURE
	
func before_run(actor: Node, _blackboard: Blackboard) -> void:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
		
	var unit_actions:UnitActions = unit.get_or_add_actions()
	var load_target:Node3D = blackboard.asset_load
	if load_target:
		unit_actions.load_into(load_target)
	else:
		var target_node:Node3D = blackboard.target_node
		if unit_actions.get_attack_target() != target_node:
			unit_actions.attack(target_node)
		else:
			_state = 1
			return
	
	var command_id := unit_actions.last_command_id
	directive.notify_command(command_id)
	_state = 0

	SignalUtils.connect_with_predicated_disconnect(unit_actions.command_finished,
		func(in_command_id:int, destroy:Signal) -> void:
			if in_command_id == command_id:
				_state = 1
				destroy.emit()
	, str(command_id))
