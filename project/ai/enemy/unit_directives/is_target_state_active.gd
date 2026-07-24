@tool
extends ActionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	var blackboard:UnitDirectiveBlackboard = _blackboard
	return SUCCESS if blackboard.target_state.active and blackboard.target_node else FAILURE
