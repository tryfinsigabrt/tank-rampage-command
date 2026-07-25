@tool
extends ConditionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	var blackboard:UnitDirectiveBlackboard = _blackboard
	var explorer:Unit = blackboard.target_node as Unit
	return SUCCESS if explorer and UnitContainerComponent.has_component(explorer) else FAILURE
