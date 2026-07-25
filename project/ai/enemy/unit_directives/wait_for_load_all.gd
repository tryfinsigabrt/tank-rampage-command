@tool
extends ActionLeaf

func tick(actor: Node, _blackboard: Blackboard) -> int:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
	
	var container := UnitContainerComponent.get_component(unit)
	if not container:
		return FAILURE
	
	if container.is_full:
		return SUCCESS
	
	var requested_units := blackboard.load_units
	# Check all units are in the container
	var container_units := container.units
	
	for requested_unit in requested_units:
		if requested_unit not in container_units:
			return RUNNING
	
	return SUCCESS
