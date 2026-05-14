class_name BaseDefense extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

@export
var base_defense_v_threat:Curve

var _occupied_units:Dictionary[int,bool] = {}

class Score:
	var unit:Unit
	var score:float
	var strength:float
	
func reserve_defenders(total_attackers:Array[Unit]) -> Array[Unit]:
	var defenders:Dictionary[int,int] = blackboard.base_defend_units
	_remove_invalid_entries(defenders)
	
	var total_enemies:int = blackboard.visible_enemy_count
	if total_enemies == 0:
		return total_attackers

	var all_buildings: Array[Building] = blackboard.team_info.buildings

	if not total_attackers or not all_buildings:
		return total_attackers
	
	_occupied_units.clear()	
	
	for defender_id in defenders:
		_occupied_units[defender_id] = true
	
	# Set blackboard key and return other available units for attacks
	#var buildings_under_attack: Array[Building] = blackboard.buildings_under_attack
	var currently_attacking: Dictionary[int,int] = blackboard.currently_attacking
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
	
	for building in candidate_buildings:
		var ideal_base_defense:float = building.attributes.defense_strength * defense_scale
		var bounds:Bounds = Bounds.new(building.get_global_bounds(), building.bounds_type)
		var building_pos:Vector3 = building.global_position
		var building_id := building.get_instance_id()

		var current_defense:float = 0.0
		
		var cnt:int = 0
		for unit in total_attackers:
			var unit_attr:TeamAssetAttributes = unit.attributes
			if not unit_attr:
				continue
			var unit_strength:float = unit_attr.strength
			var unit_id := unit.get_instance_id()
	
			# If the unit is already in attack range of the building then count it toward defense\
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
		# for every attacker
		
		# No new defenders required - go to next building
		if cnt == 0:
			continue
			
		for i in range(cnt, unit_scores.size()):
			unit_scores[cnt].score = -1
			
		unit_scores.sort_custom(func(a:Score, b:Score) -> bool:
			return a.score > b.score	
		)
		
		for i in cnt:
			var score := unit_scores[i]
			var unit := score.unit
			var unit_id := unit.get_instance_id()
			
			defenders[unit_id] = building_id
			_occupied_units[unit_id] = true
			current_defense += score.strength
			if current_defense >= ideal_base_defense:
				break
	# for All buildings
	
	if not defenders:
		return total_attackers
	
	var final_attackers:Array[Unit]
	for unit in total_attackers:
		if unit.get_instance_id() not in defenders:
			final_attackers.push_back(unit)
	
	return final_attackers

func _remove_invalid_entries(defenders:Dictionary[int,int]) -> void:
	for defender_id:int in defenders.keys():
		if not is_instance_id_valid(defender_id):
			defenders.erase(defender_id)
			continue
		var building_id:int = defenders[defender_id]
		if not is_instance_id_valid(building_id):
			defenders.erase(defender_id)
