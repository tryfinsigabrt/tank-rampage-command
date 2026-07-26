@tool
class_name HoldActionLeaf extends ActionLeaf

var _command_id:int
var _state:int

var _start_time:float
var _duration:float

@export
var expected_pos_tolerance:float = 10.0

func _should_end_hold() -> bool:
	return GameManager.game_timer.time_seconds >= _start_time + _duration
	
func tick(actor: Node, _blackboard: Blackboard) -> int:
	if _state == 0 and _should_end_hold():
		
		if LogUtils.debug:
			print_debug("%s: Hold duration of %.1fs reached" % [name, _duration])
		_state = 1
		
		var directive:AiUnitDirectives = actor
		var unit:Unit = directive.unit
		
		# Only stop if not in container - otherwise just stay in there until a new order is issued
		if not UnitContainerComponent.is_in_container(unit):
			unit.get_or_add_actions().stop()
	
	match _state:
		0: return RUNNING
		1: return SUCCESS
		_: return FAILURE

func before_run(actor: Node, _blackboard: Blackboard) -> void:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
	
	# Check if unit is in container. If so then skip hold
	var loaded_asset:Node3D = blackboard.asset_load
	var skip_hold:bool = false
	if loaded_asset:
		var container := UnitContainerComponent.get_component(loaded_asset)
		var unit_container := UnitContainerComponent.get_container_for_unit(unit)
		if container == unit_container:
			skip_hold = true
	
	if not skip_hold:
		var position:Vector3 = blackboard.position
		
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
	_duration = blackboard.time

	if not skip_hold:
		var unit_actions:UnitActions = unit.get_or_add_actions()
		SignalUtils.connect_with_predicated_disconnect(unit_actions.command_finished,
			func(command_id:int, destroy:Signal) -> void:
				if command_id == _command_id and _state == 0:
					_state = -1
					destroy.emit()
		, str(_command_id))
