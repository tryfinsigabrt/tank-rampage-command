@tool
extends ConditionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	var blackboard:UnitDirectiveBlackboard = _blackboard
	# Check that followed target is still valid and the command hasn't finished
	return SUCCESS if blackboard.target_node and blackboard.target_state.active else FAILURE
