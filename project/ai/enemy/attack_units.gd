@tool
extends ActionLeaf
	
func tick(_actor: Node, in_blackboard: Blackboard) -> int:
	var blackboard: EnemyTeamBlackboard = in_blackboard
	
	var currently_attacking:Dictionary[int, int] = blackboard.currently_attacking
	
	if not currently_attacking:
		return SUCCESS
		
	var attack_priorities := blackboard.attack_priorities
	var attack_priority_map:Dictionary[int, AttackPriority]
	for priority in attack_priorities:
		var target:Node3D = priority.target
		if is_instance_valid(target):
			attack_priority_map[target.get_instance_id()] = priority
	
	# Make sure we issue attack directives
	for unit_id in currently_attacking:
		var unit:Unit = instance_from_id(unit_id) as Unit
		if not unit:
			print_debug("%s: Attacker with id=%d is no longer valid" % [name, unit_id])
			continue
		var target_id:int = currently_attacking[unit_id]
		var target:Node3D = instance_from_id(target_id) as Node3D
		if not target:
			print_debug("%s: Attacker(%s) ordered to attack target=%d is no longer a valid target" % [name, unit.name, target_id])
			continue
			
		var unit_directives := AiUnitDirectives.get_component(unit)
		
		var priority:int = 5
		var attack_priority:AttackPriority = attack_priority_map.get(target_id)
		if attack_priority:
			priority += floori(attack_priority.weight / 10.0)
		unit_directives.set_attack_target(target, priority)
	
	return SUCCESS
