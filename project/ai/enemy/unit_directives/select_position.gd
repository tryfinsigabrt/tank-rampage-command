@tool
extends ActionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	var blackboard:UnitDirectiveBlackboard = _blackboard
	
	var load_target:Node3D = _get_available_load_target_if_applicable(blackboard)
	
	if load_target:
		blackboard.set_load_into_target(load_target)
	else:
		blackboard.execute_position_callback()
	
	return SUCCESS

func _get_available_load_target_if_applicable(blackboard:UnitDirectiveBlackboard) -> Node3D:
	# TODO: Implement with bunker sweeper - choosing if available
	return null
