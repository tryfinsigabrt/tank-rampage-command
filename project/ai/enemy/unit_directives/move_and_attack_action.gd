@tool
extends ActionLeaf

@export
var position_blackboard_key:StringName = UnitDirectiveBlackboard.Keys.Position

var _command_id:int
var _running:bool

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	return RUNNING if _running else SUCCESS
	
func before_run(actor: Node, _blackboard: Blackboard) -> void:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
		
	var unit_actions:UnitActions = unit.get_or_add_actions()
	var load_target:Node3D = blackboard.asset_load
	if load_target:
		unit_actions.load_into(load_target)
	else:
		var position:Vector3 = blackboard.get_vector_value(position_blackboard_key)
		if position == Vector3.INF:
			_running = false
			return
			
		var heading_bias:Vector3 = blackboard.heading_bias
		
		if unit.weapon and not heading_bias:
			unit_actions.move_and_attack(position)
		else:
			unit_actions.move(position)
	
	_command_id = unit_actions.last_command_id
	directive.notify_command(_command_id)
	_running = true

	SignalUtils.connect_with_predicated_disconnect(unit_actions.command_finished,
		func(command_id:int, destroy:Signal) -> void:
			if command_id == _command_id:
				_running = false
				destroy.emit()
	, str(_command_id))
