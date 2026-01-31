extends ConditionLeaf

func tick(_actor: Node, blackboard: Blackboard) -> int:
	return SUCCESS if blackboard.currently_attacking or blackboard.attack_priorities else FAILURE
