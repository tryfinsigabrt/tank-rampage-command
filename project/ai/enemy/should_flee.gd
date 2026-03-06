@tool
extends ConditionLeaf

func tick(_actor: Node, blackboard: Blackboard) -> int:
	var result:int = SUCCESS if blackboard.avoidance_enemies else FAILURE
	return result
