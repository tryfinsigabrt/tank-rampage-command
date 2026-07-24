@tool
extends ActionLeaf

var _follow_distance:float
var _follow_pause_switch_time:float
var _next_execution_time:float

var _unit:Unit
var _leader:Unit
var _game_unit_nav:GameUnitNavigation

var _follower_bounds:BoundingCircle
var _leader_bounds:BoundingCircle

func before_run(actor: Node, blackboard: Blackboard) -> void:
	_follow_distance = blackboard.get_value(UnitBlackboard.Keys.FollowDistance, 0.0)
	_follow_pause_switch_time = blackboard.get_value(UnitBlackboard.Keys.FollowMovementChangeInterval, 0.0)
	_next_execution_time = 0.0
	
	_unit = actor as Unit
	_game_unit_nav = GameUnitNavigation.get_component(_unit) if _unit else null
	_leader = blackboard.get_value(UnitBlackboard.Keys.TargetNode)
	
	if is_instance_valid(_unit):
		_follower_bounds = _create_bounding_circle(_unit)
	if is_instance_valid(_leader):
		_leader_bounds = _create_bounding_circle(_leader)
		
func tick(_actor: Node, _blackboard: Blackboard) -> int:
	if not is_instance_valid(_unit) or not is_instance_valid(_game_unit_nav) or not is_instance_valid(_leader):
		return FAILURE
		
	var time:float = GameManager.game_timer.time_seconds
	if time < _next_execution_time:
		return RUNNING
		
	_set_bounds_pos(_leader, _leader_bounds)
	_set_bounds_pos(_unit, _follower_bounds)
	
	var dist:float = _leader_bounds.distance_to_bounds(_follower_bounds)
	
	var should_pause:bool = dist < _follow_distance
	var was_paused:bool = _game_unit_nav.paused
	_game_unit_nav.paused = should_pause
	#print("SHOULD PAUSE = %s" % should_pause)
	if should_pause != was_paused:
		_next_execution_time = time + _follow_pause_switch_time
	return RUNNING

func _create_bounding_circle(unit:Unit) -> BoundingCircle:
	return BoundingCircle.from_aabb(unit.get_bounds(), true)
	
func _set_bounds_pos(unit:Unit, circle:BoundingCircle) -> void:
	var pos:Vector3 = unit.global_position
	circle.center = Vector2(pos.x, pos.z)
