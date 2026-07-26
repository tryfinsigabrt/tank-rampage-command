extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var base_defense: BaseDefense = $BaseDefense

@export_group("Priority Reassignment", "priority")

## Min priority factor increase to re-assign a unit's attack priority to a higher priority target
@export
var priority_min_increase_factor_attack_change:float = 2.0

## Min elapsed time attacking current target before re-assigning
@export
var priority_min_elapsed_time:float = 5.0

@export
var priority_max_travel_time:float = 7.0

func _on_attacking_priorities_changed() -> void:
	_execute()

func _on_attacking_units_changed() -> void:
	await get_tree().process_frame
	_execute()

# Mapping unit being attacked to who is attacking it
var _currently_attacking_mapping:Dictionary[int,PackedInt64Array] = {}
var _new_attacks:Array[AttackPriority]
var _attacker_pool:Array[Unit]
var _tmp_units:Array[Unit]

func _ready() -> void:
	SignalBus.on_unit_command_finished.connect(_on_command_finished)

func _execute() -> void:
	var currently_attacking:Dictionary[int, AttackPriority] = blackboard.currently_attacking
	var attack_priorities:Array[AttackPriority] = blackboard.attack_priorities
		
	# See if select new units to attack
	_new_attacks.clear()
	_attacker_pool.clear()
	_tmp_units.clear()
	
	var total_weight:float = 0.0	
	for priority in attack_priorities:
		var target:Node3D = priority.target
		if is_instance_valid(target) and target.get_instance_id() not in _currently_attacking_mapping:
			_new_attacks.push_back(priority)
			total_weight += priority.weight
	
	if not _new_attacks:
		return
	
	# Attacking prioritized over other non-defensive actions, so not using idle here
	var attack_pool_units := base_defense.reserve_defenders(TeamUnits.get_potential_attackers(blackboard.team_info.units))
	var potential_reassignments:Dictionary[int, Array]
	
	var current_time:float = GameManager.game_timer.time_seconds
	
	for unit in attack_pool_units:
		var unit_id:int = unit.get_instance_id()
		var current_priority:AttackPriority = currently_attacking.get(unit_id)
		if not current_priority:
			_attacker_pool.push_back(unit)
		else: # See if there are overriding priority possibilities
			for new_target in _new_attacks:
				var decision:int = _score_priority_replacement(unit, current_time, current_priority, new_target)
				# -1 means it fails the basic priority or time criteria 
				# 0 means it failed a target-specific requirement
				# 1 means it passese
				if decision > 0:
					var target_id:int = new_target.target_id
					var candidates:Array[Unit] = potential_reassignments.get(target_id, [] as Array[Unit])
					if not candidates:
						potential_reassignments[target_id] = candidates
					candidates.push_back(unit)
				elif decision < 0:
					# Sorted by priority so can exit the loop early if 
					break
	
	if not _attacker_pool and not potential_reassignments:
		# Nothing new to do - keep thrashing the enemy!
		return

	for new_priority in _new_attacks:
		var new_target := new_priority.target
		var weight:float = new_priority.weight / total_weight
		
		# See who's available
		var target_id:int = new_target.get_instance_id()
		
		var attacker_list:PackedInt64Array
		if target_id in _currently_attacking_mapping:
			attacker_list = _currently_attacking_mapping[target_id]

		var count:int = attacker_list.size()
		
		_tmp_units.clear()
		
		var num_attackers:int = _attacker_pool.size()
		var potential_attackers:Array[Unit] = potential_reassignments.get(target_id, [] as Array[Unit])
		num_attackers += potential_attackers.size()

		var units_per_target:int = ceili(num_attackers * weight)
		
		for attacker in _attacker_pool:
			var available_unit_id:int = attacker.get_instance_id()
			currently_attacking[available_unit_id] = new_priority
			attacker_list.push_back(available_unit_id)
			count += 1
			_tmp_units.push_back(attacker)
			if count >= units_per_target:
				break
		
		if count < units_per_target:
			for attacker in potential_attackers:
				var attacker_id:int = attacker.get_instance_id()
				# Remove existing mapping
				_remove_current_attack_mapping(attacker_id, currently_attacking.get(attacker_id))
				currently_attacking[attacker_id] = new_priority
				attacker_list.push_back(attacker_id)
				count += 1
				_tmp_units.push_back(attacker)
				if count >= units_per_target:
					break
					
		# TODO: Technically the idle units will be updated once the command starts but that won't happen on this tick necessarily
		for occupied_unit in _tmp_units:
			_attacker_pool.erase(occupied_unit)
		
		if attacker_list:
			_currently_attacking_mapping[target_id] = attacker_list
	
	if _new_attacks:
		blackboard.currently_attacking = currently_attacking
	
func _score_priority_replacement(attacker:Unit, current_time:float, current_priority:AttackPriority, new_priority:AttackPriority) -> int:
	if current_time - current_priority.time < priority_min_elapsed_time:
		return -1
	
	if new_priority.weight < current_priority.weight * priority_min_increase_factor_attack_change:
		return -1
	
	var dist:float = attacker.global_position.distance_to(new_priority.target.global_position)
	var time:float = dist / attacker.movement_speed
	return 1 if time <= priority_max_travel_time else 0

func _remove_current_attack_mapping(unit_id:int, attack_priority:AttackPriority) -> void:
	if not attack_priority:
		return
		
	var target_id:int = attack_priority.target_id
	var attackers:PackedInt64Array = _currently_attacking_mapping.get(target_id, PackedInt64Array())
	attackers.erase(unit_id)
	if not attackers:
		_currently_attacking_mapping.erase(target_id)
		
func _on_command_finished(unit:Unit, command:StringName, _command_id:int, command_args:Dictionary[StringName, Variant]) -> void:
	#target_node
	if command == UnitBlackboard.Action.Attack and is_instance_valid(unit) and unit.is_on_team(blackboard.team):
		print_debug("%s: unit=%s finished attacking" % [name, unit.name])
		
		var attacker_mapper: Dictionary[int,AttackPriority] = blackboard.currently_attacking
		var attacker_id:int = unit.get_instance_id()

		var target_info:AttackPriority = attacker_mapper.get(attacker_id)
		var target_id:int = command_args.get(&"target_id", 0)
		
		# Only remove attacking mapping for unit if the command that finished was the active one
		if not target_info or target_id != target_info.target_id:
			return
			
		attacker_mapper.erase(attacker_id)
		
		# If the target was destroyed then just remove the array entry and let the UnitViabilityChecker update the currently_attacking array
		if not is_instance_id_valid(target_id):
			print_debug("%s: target=%d destroyed" % [name, target_id])
			_currently_attacking_mapping.erase(target_id)
		else:			
			# Be sure to remove the attacking mapping if it was previously recorded that this unit was attacking that target
			var attackers:PackedInt64Array = _currently_attacking_mapping.get(target_id, PackedInt64Array())
			if attackers:
				attackers.erase(attacker_id)
				if attackers:
					# Others still attacking - keep in currently attacking
					if LogUtils.debug:
						print_debug("%s: target=%d still has other attackers=%s" % [name, target_id, attackers])
				else:
					print_debug("%s: target=%d has no more attackers" % [name, target_id])
					_currently_attacking_mapping.erase(target_id)
			else:
				push_warning("%s: unit=%s finished attacking target_id but could not find attackers mapping for target" % [name, unit.name])
			
		blackboard.currently_attacking = attacker_mapper
