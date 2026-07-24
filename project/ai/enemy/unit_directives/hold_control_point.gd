@tool
extends HoldActionLeaf

var _control_point:ControlPoint

var _team:int
var _hold_time_start:float = -1.0

func _should_end_hold() -> bool:
	if not is_instance_valid(_control_point):
		return true
	# Make sure team has control and isn't contested
	if _control_point.is_constested() or _control_point.owned_team != _team:
		_hold_time_start = -1.0
		return false
	
	var current_time:float = GameManager.game_timer.time_seconds
	if _hold_time_start <= 0.0:
		_hold_time_start = current_time
	
	# See if held long enough
	return current_time >= _hold_time_start + _duration
	
func before_run(actor: Node, _blackboard: Blackboard) -> void:
	super.before_run(actor, _blackboard)
	
	_control_point = null
	_team = 0
	_hold_time_start = -1.0
	
	# Already completed
	if _state != 0:
		return
		
	var blackboard:UnitDirectiveBlackboard = _blackboard
	
	var directive:AiUnitDirectives = actor
	_team = directive.unit.team
	
	_control_point = blackboard.control_point
	if not _control_point:
		push_warning("%s: Control Point Hold requested, but control point is not valid" % name)
		_state = -1
		return
