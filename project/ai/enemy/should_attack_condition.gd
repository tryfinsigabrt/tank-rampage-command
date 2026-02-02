@tool
extends ConditionLeaf

func tick(_actor: Node, blackboard: Blackboard) -> int:
	var result:int = SUCCESS if blackboard.currently_attacking or blackboard.attack_priorities else FAILURE
	return result
