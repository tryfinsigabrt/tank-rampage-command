@tool
extends ActionLeaf
	
func tick(_actor: Node, in_blackboard: Blackboard) -> int:
	var blackboard: EnemyTeamBlackboard = in_blackboard
	
	var currently_attacking:Dictionary[int, AttackPriority] = blackboard.currently_attacking
	
	if not currently_attacking:
		return SUCCESS
			
	# Make sure we issue attack directives
	for unit_id in currently_attacking:
		var unit:Unit = instance_from_id(unit_id) as Unit
		if not unit:
			print_debug("%s: Attacker with id=%d is no longer valid" % [name, unit_id])
			continue
		var target_info:AttackPriority = currently_attacking[unit_id]
		var target := target_info.target
		if not is_instance_valid(target):
			print_debug("%s: Attacker(%s) ordered to attack target %d that was no longer valid" % [name, target_info.target_id, unit.name])
			continue
			
		var unit_directives := AiUnitDirectives.get_component(unit)
		
		var priority:int = 5
		priority += floori(target_info.weight / 10.0)
		unit_directives.set_attack_target(target, priority)
	
	return SUCCESS
