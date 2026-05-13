class_name AttackPrioritizer extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

func prioritize_targets(targets:Array[Unit]) -> Array[AttackPriority]:
	var priorities:Array[AttackPriority]
	if not targets:
		return priorities
		
	priorities.resize(targets.size())
	
	for i in priorities.size():
		priorities[i] = AttackPriority.new(targets[i])
	
	var buildings_under_attack:Array[Building] = blackboard.buildings_under_attack
	var building_attackers:Array[Array]
	var building_value_weights:PackedFloat32Array
	
	if buildings_under_attack:
		building_attackers.resize(buildings_under_attack.size())	
		for i in building_attackers.size():
			var building:Building = buildings_under_attack[i]
			var attacked_tracker_component:AttackedTrackerComponent = AttackedTrackerComponent.get_component(building, false)
			if not attacked_tracker_component:
				continue
			building_attackers[i] = attacked_tracker_component.get_visible_attacker_units()
			
		building_value_weights.resize(buildings_under_attack.size())
		for i in building_value_weights.size():
			var building:Building = buildings_under_attack[i]
			var cost:ConstructionResource = ConstructionResource.get_assigned_resource(building)
			if cost:
				building_value_weights[i] = cost.cost / 500.0
	
	for priority in priorities:
		var unit := priority.unit
		var weight:float = priority.weight
		
		var attack_priorities: TeamAssetAttributes = unit.attributes
		if attack_priorities:
			weight += maxf(2.0 - attack_priorities.attack_priority, 0.0)
			weight += attack_priorities.strength / 10.0
	
		for i in building_attackers.size():
			var attackers:Array = building_attackers[i]
			if unit in attackers:
				weight += building_value_weights[i]
		
		priority.weight = weight
	
	priorities.sort_custom(func(a:AttackPriority, b:AttackPriority) -> bool:
		return a.weight > b.weight
	)
	
	return priorities
