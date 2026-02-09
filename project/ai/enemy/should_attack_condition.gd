@tool
extends ConditionLeaf

func tick(_actor: Node, blackboard: Blackboard) -> int:
	var result:int = SUCCESS if blackboard.currently_attacking else FAILURE
	return result
