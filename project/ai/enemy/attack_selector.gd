extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var base_defense: BaseDefense = $BaseDefense

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
	SignalBus.on_unit_command_finished.connect(_on_command_finished.unbind(2))

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
	
	# Attacking prioritized over other actions, so not using idle here
	var attack_pool_units := base_defense.reserve_defenders(blackboard.team_info.units)
	for unit in attack_pool_units:
		if unit.get_instance_id() not in currently_attacking:
			_attacker_pool.push_back(unit)
	
	if not _attacker_pool:
		# Nothing new to do - keep thrashing the enemy!
		return

	# TODO: Limit number of attackers based on active threats and reserve some units to defend base
	# Select units to defend base and then have a separate action for that that runs after attack enemies
	var num_attackers:int = _attacker_pool.size()

	for new_priority in _new_attacks:
		var new_target := new_priority.target
		var weight:float = new_priority.weight / total_weight
		
		# See who's available
		var target_id:int = new_target.get_instance_id()
		
		var attacker_list:PackedInt64Array
		if target_id in _currently_attacking_mapping:
			attacker_list = _currently_attacking_mapping[target_id]

		var count:int = 0
		
		_tmp_units.clear()
		
		var units_per_target:int = ceili(num_attackers * weight)
		
		for attacker in _attacker_pool:
			var available_unit_id:int = attacker.get_instance_id()
			currently_attacking[available_unit_id] = new_priority
			attacker_list.push_back(available_unit_id)
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
	
func _on_command_finished(unit:Unit, command:StringName) -> void:
	if command == UnitBlackboard.Action.Attack and is_instance_valid(unit) and unit.is_on_team(blackboard.team):
		print_debug("%s: unit=%s finished attacking" % [name, unit.name])
		
		var attacker_mapper: Dictionary[int,AttackPriority] = blackboard.currently_attacking
		var attacker_id:int = unit.get_instance_id()

		var target_info:AttackPriority = attacker_mapper.get(attacker_id)		
		if not target_info:
			# FIXME: Slow path - Need to go through and remove from values
			# This is happening because the currently_attacking blackboard list has already been updated before the command finishes
			for other_target_id:int in _currently_attacking_mapping.keys():
				var valid:bool = is_instance_id_valid(other_target_id)
				if valid:
					var attackers: PackedInt64Array = _currently_attacking_mapping[other_target_id]
					attackers.erase(attacker_id)
					valid = not attackers.is_empty()
				if not valid:
					_currently_attacking_mapping.erase(other_target_id)
		else:
			attacker_mapper.erase(attacker_id)

			# If the target was destroyed then just remove the array entry and let the UnitViabilityChecker update the currently_attacking array
			var target_id:int = target_info.target_id
			if not target_info.valid:
				print_debug("%s: target=%d destroyed" % [name, target_id])
				_currently_attacking_mapping.erase(target_id)
			else:			
				# See if others are still attacking
				var attackers:PackedInt64Array = _currently_attacking_mapping.get(target_id, PackedInt64Array())
				if attackers:
					attackers.erase(attacker_id)
					if attackers:
						# Others still attacking - keep in currently attacking
						print_debug("%s: target=%d still has other attackers=%s" % [name, target_id, attackers])
					else:
						print_debug("%s: target=%d has no more attackers" % [name, target_id])
						_currently_attacking_mapping.erase(target_id)
				else:
					push_warning("%s: unit=%s finished attacking target_id but could not find attackers mapping for target" % [name, unit.name])
			
		blackboard.currently_attacking = attacker_mapper
