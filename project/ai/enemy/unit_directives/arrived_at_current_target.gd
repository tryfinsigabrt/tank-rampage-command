@tool
extends ActionLeaf

func tick(actor: Node, _blackboard: Blackboard) -> int:
	# See if already in the bounds
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
	var bounds:BoundingSphere = blackboard.bounds
	
	if not bounds:
		return FAILURE
	
	var current_pos:Vector3 = unit.global_position
	
	if bounds.contains(current_pos):
		return SUCCESS
		
	return RUNNING
