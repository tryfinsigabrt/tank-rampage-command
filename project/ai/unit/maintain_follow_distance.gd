@tool
extends ActionLeaf

var _follow_distance_sq:float
var _unit:Unit
var _leader:Unit
var _game_unit_nav:GameUnitNavigation

func before_run(actor: Node, blackboard: Blackboard) -> void:
	_follow_distance_sq = blackboard.get_value(UnitBlackboard.Keys.FollowDistance, 0.0) ** 2
	_unit = actor as Unit
	_game_unit_nav = Groups.get_child_with_type(_unit, GameUnitNavigation) if _unit else null
	_leader = blackboard.get_value(UnitBlackboard.Keys.TargetNode)
	
func tick(_actor: Node, _blackboard: Blackboard) -> int:
	if not is_instance_valid(_unit) or not is_instance_valid(_game_unit_nav) or not is_instance_valid(_leader):
		return FAILURE
	
	var should_pause:bool = _unit.global_position.distance_squared_to(_leader.global_position) < _follow_distance_sq
	_game_unit_nav.paused = should_pause
	
	return RUNNING
