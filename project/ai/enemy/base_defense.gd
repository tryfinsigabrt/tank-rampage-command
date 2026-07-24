class_name BaseDefense extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

@export
var base_defense_v_threat:Curve

@export
var structure_defense_bounds_factor:float = 1.5

var _occupied_units:Dictionary[int,bool] = {}

class Score:
	var unit:Unit
	var score:float
	var strength:float
	
func reserve_defenders(total_attackers:Array[Unit]) -> Array[Unit]:
	var defenders:Dictionary[int,EnemyTeamBlackboard.BaseDefenseContext] = blackboard.base_defend_units
	var changed:bool = _remove_invalid_entries(defenders)
	
	var total_enemies:int = blackboard.visible_enemy_count
	if total_enemies == 0:
		if changed:
			blackboard.on_defense_units_updated.emit()
		return total_attackers

	var all_buildings: Array[Building] = blackboard.team_info.buildings
	var all_structures: Array[DefensiveStructure] = blackboard.team_info.structures

	if not total_attackers or not all_buildings:
		if changed:
			blackboard.on_defense_units_updated.emit()
		return total_attackers
	
	_occupied_units.clear()	
	
	for defender_id in defenders:
		_occupied_units[defender_id] = true
	
	# Set blackboard key and return other available units for attacks
	#var buildings_under_attack: Array[Building] = blackboard.buildings_under_attack
	var currently_attacking: Dictionary[int,AttackPriority] = blackboard.currently_attacking
	for attacker_id in currently_attacking:
		_occupied_units[attacker_id] = true
		
	var total_units:int = total_attackers.size()
	var threat_fraction:float = float(total_enemies) / total_units
	var defense_scale:float = base_defense_v_threat.sample(threat_fraction) if base_defense_v_threat else 1.0

	var candidate_buildings:Array[Building]
	for building in all_buildings:
		var attr := building.attributes
		if attr and attr.defense_strength * defense_scale >= 0.5:
			candidate_buildings.push_back(building)
			
	candidate_buildings.sort_custom(func(a:Building, b:Building) -> bool:
		var a_attr := a.attributes
		var b_attr := b.attributes
		return a_attr.defense_strength > b_attr.defense_strength
	)

	var unit_scores:Array[Score]
	
	blackboard.defense_needs_are_updating.emit(EnemyTeamBlackboard.DefenseNeedType.BUILDING, true)

	for building in candidate_buildings:
		var ideal_base_defense:float = building.attributes.defense_strength * defense_scale
		var bounds:Bounds = Bounds.new(building.get_global_bounds(), building.bounds_type)
		var structure_influence_bounds:Bounds = bounds.expand_by(bounds.radius * structure_defense_bounds_factor)
		var building_pos:Vector3 = building.global_position
		var building_id := building.get_instance_id()

		var current_defense:float = 0.0
		var requested_defense:float = 0.0
		
		for structure in all_structures:
			# See if in range - either via weapon targeting component for structures like bunker or turret
			# or if the structure is the weapon itself then just check the bounds
			var weapon_targeting_component:WeaponTargetingComponent = WeaponTargetingComponent.get_component(structure, false)
			if weapon_targeting_component and weapon_targeting_component.is_in_range_bounds(bounds):
				current_defense += weapon_targeting_component.get_weapon_strength()
			elif not weapon_targeting_component and structure_influence_bounds.overlaps(Bounds.new(structure.get_global_bounds(), structure.bounds_type)):
				var attr:TeamAssetAttributes = structure.attributes
				if attr:
					current_defense += attr.strength
			if current_defense >= ideal_base_defense:
				break
				
		var cnt:int = 0
		if current_defense < ideal_base_defense:
			for unit in total_attackers:
				var unit_attr:TeamAssetAttributes = unit.attributes
				if not unit_attr:
					continue
				var unit_strength:float = unit_attr.strength
				var unit_id := unit.get_instance_id()
		
				# If the unit is already in attack range of the building then count it toward defense
				var current_defended_building:int = defenders.get(unit_id, -1)
				if current_defended_building == building_id or unit.weapon.is_in_range_bounds(bounds):
					current_defense += unit_strength
					if current_defense >= ideal_base_defense:
						break
				else:
					if unit_id in _occupied_units:
						continue
					var unit_pos:Vector3 = unit.global_position
					var dist_sq:float = unit_pos.distance_squared_to(building_pos)
					# Dist has to be > 0 if weapon not in range
					var score:float = unit_strength / dist_sq
					var entry:Score
					if cnt < unit_scores.size():
						entry = unit_scores[cnt]
					else:
						entry = Score.new()
						unit_scores.push_back(entry)
					entry.unit = unit
					entry.score = score
					entry.strength = unit_strength
					cnt += 1
					requested_defense += unit_strength
			# for every attacker
		# if attackers required
		
		var base_defense_context := EnemyTeamBlackboard.BaseDefenseContext.new()
		base_defense_context.asset_id = building_id
		base_defense_context.current_defense = current_defense
		base_defense_context.ideal_defense = ideal_base_defense
		base_defense_context.bounds = bounds
		base_defense_context.requested_defense = requested_defense
		base_defense_context.requested_count = cnt

		blackboard.defense_need_updated.emit(EnemyTeamBlackboard.DefenseNeedType.BUILDING, base_defense_context)

		# No new defenders required - go to next building
		if cnt == 0:
			continue
			
		for i in range(cnt, unit_scores.size()):
			unit_scores[cnt].score = -1
			
		unit_scores.sort_custom(func(a:Score, b:Score) -> bool:
			return a.score > b.score	
		)
		
		changed = true
		
		for i in cnt:
			var score := unit_scores[i]
			var unit := score.unit
			var unit_id := unit.get_instance_id()
			
			defenders[unit_id] = base_defense_context
			_occupied_units[unit_id] = true
			current_defense += score.strength
			if current_defense >= ideal_base_defense:
				break
	# for All buildings
	
	blackboard.defense_needs_are_updating.emit(EnemyTeamBlackboard.DefenseNeedType.BUILDING, false)

	if not defenders:
		if changed:
			blackboard.on_defense_units_updated.emit()
		return total_attackers
	
	var final_attackers:Array[Unit]
	for unit in total_attackers:
		if unit.get_instance_id() not in defenders:
			final_attackers.push_back(unit)
	
	if changed:
		blackboard.on_defense_units_updated.emit()
		
	return final_attackers

func _remove_invalid_entries(defenders:Dictionary[int, EnemyTeamBlackboard.BaseDefenseContext]) -> bool:
	var changed:bool = false
	for defender_id:int in defenders.keys():
		if not is_instance_id_valid(defender_id):
			defenders.erase(defender_id)
			changed = true
			continue
		var context: EnemyTeamBlackboard.BaseDefenseContext = defenders[defender_id]
		var building_id:int = context.asset_id
		if not is_instance_id_valid(building_id):
			defenders.erase(defender_id)
			changed = true
	return changed
