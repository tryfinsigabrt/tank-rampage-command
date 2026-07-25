@tool
extends ActionLeaf

@export
var load_target_key:StringName

var _status:int

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	return _status
	
func before_run(actor: Node, _blackboard: Blackboard) -> void:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
		
	var load_target:Node3D = blackboard.get_value(load_target_key) as Node3D
	if not load_target:
		_status = FAILURE
		return
	
	# Make sure have capacity
	var container := UnitContainerComponent.get_component(load_target)
	if not container or container.is_full:
		_status = FAILURE
		return
		
	var unit_actions:UnitActions = unit.get_or_add_actions()
	unit_actions.load_into(load_target)
	
	var command_id := unit_actions.last_command_id
	directive.notify_command(command_id)
	_status = RUNNING

	SignalUtils.connect_with_predicated_disconnect(unit_actions.command_finished,
		func(in_command_id:int, destroy:Signal) -> void:
			if in_command_id == command_id:
				_status = SUCCESS
				destroy.emit()
	, str(command_id))
