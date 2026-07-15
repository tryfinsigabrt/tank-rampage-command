@tool
extends ActionLeaf
	
func tick(_actor: Node, in_blackboard: Blackboard) -> int:
	var blackboard: EnemyTeamBlackboard = in_blackboard
	
	var currently_attacking:Dictionary[int, int] = blackboard.currently_attacking
	
	# Make sure we issue attack directives
	for unit_id in currently_attacking:
		var unit:Unit = instance_from_id(unit_id) as Unit
		if not unit:
			print_debug("%s: Attacker with id=%d is no longer valid" % [name, unit_id])
			continue
		var target_id:int = currently_attacking[unit_id]
		var target:Unit = instance_from_id(target_id) as Unit
		if not target:
			print_debug("%s: Attacker(%s) ordered to attack target=%d is no longer a valid target" % [name, unit.name, target_id])
			continue
			
		var unit_directives := AiUnitDirectives.get_component(unit)
		unit_directives.set_attack_target(target, 5)
	
	return SUCCESS
