@tool
extends ConditionLeaf

func tick(actor: Node, _blackboard: Blackboard) -> int:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	return SUCCESS if UnitContainerComponent.has_component(unit) else FAILURE
