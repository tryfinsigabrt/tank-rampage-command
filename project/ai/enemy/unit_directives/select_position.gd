@tool
extends ActionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	var blackboard:UnitDirectiveBlackboard = _blackboard
	blackboard.execute_position_callback()
	
	return SUCCESS
