@tool
extends ActionLeaf

var _command_id:int
var _state:int

var _start_time:float
var _end_time:float

@export
var expected_pos_tolerance:float = 10.0

func tick(actor: Node, _blackboard: Blackboard) -> int:
	if _state == 0 and GameManager.game_timer.time_seconds >= _end_time:
		print_debug("%s: Hold duration of %.1fs reached" % [name, _end_time - _start_time])
		_state = SUCCESS
		
		var directive:AiUnitDirectives = actor
		var unit:Unit = directive.unit
		unit.get_or_add_actions().stop()
	
	match _state:
		0: return RUNNING
		1: return SUCCESS
		_: return FAILURE

func before_run(actor: Node, _blackboard: Blackboard) -> void:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
	
	var position:Vector3 = blackboard.position
	var duration:float = blackboard.time
	
	# Make sure we are actually at the position
	var unit_pos:Vector3 = unit.get_fire_global_position()
	if unit_pos.distance_squared_to(position) >= expected_pos_tolerance * expected_pos_tolerance:
		print_debug("%s: Hold command requested, but not at requested position of %s, at %s" % [name, position, unit_pos])
		_state = -1
		return
		
	var unit_actions:UnitActions = unit.get_or_add_actions()
	unit_actions.hold()
	
	_command_id = unit_actions.last_command_id
	directive.notify_command(_command_id)

	_state = 0
	_start_time = GameManager.game_timer.time_seconds
	_end_time = _start_time + duration

	SignalUtils.connect_with_predicated_disconnect(unit_actions.command_finished,
		func(command_id:int, destroy:Signal) -> void:
			if command_id == _command_id and _state == 0:
				_state = -1
				destroy.emit()
	, str(_command_id))
