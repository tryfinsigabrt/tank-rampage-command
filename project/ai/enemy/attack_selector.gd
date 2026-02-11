extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

func _on_attacking_priorities_changed() -> void:
	_execute()

func _on_attacking_units_changed() -> void:
	await get_tree().process_frame
	_execute()

# Mapping unit being attacked to who is attacking it
var _currently_attacking_mapping:Dictionary[int,PackedInt64Array] = {}
var _new_attacks:Array[Unit]
var _attacker_pool:Array[Unit]
var _tmp_units:Array[Unit]


func _ready() -> void:
	SignalBus.on_unit_command_finished.connect(_on_command_finished.unbind(1))

func _execute() -> void:
	var currently_attacking:Dictionary[int, int] = blackboard.currently_attacking
	var attack_priorities:Array[Unit] = blackboard.attack_priorities
		
	# See if select new units to attack
	_new_attacks.clear()
	_attacker_pool.clear()
	_tmp_units.clear()
		
	for unit in attack_priorities:
		if not unit.get_instance_id() in _currently_attacking_mapping:
			_new_attacks.push_back(unit)
	
	if not _new_attacks:
		return
	
	# Attacking prioritized over other actions, so not using idle here
	_attacker_pool.append_array(blackboard.team_info.units)
	
	if not _attacker_pool:
		# Nothing new to do - keep thrashing the enemy!
		return

	# TODO: Simple strategy
	var units_per_enemy:int = ceili(float(_attacker_pool.size()) / _new_attacks.size())

	for new_target in _new_attacks:
		# See who's available
		var target_id:int = new_target.get_instance_id()
		
		var attacker_list:PackedInt64Array
		if target_id in _currently_attacking_mapping:
			attacker_list = _currently_attacking_mapping[target_id]

		var count:int = 0
		
		_tmp_units.clear()
		for attacker in _attacker_pool:
			var available_unit_id:int = attacker.get_instance_id()
			currently_attacking[available_unit_id] = target_id
			attacker_list.push_back(available_unit_id)
			count += 1
			_tmp_units.push_back(attacker)
			if count >= units_per_enemy:
				break
			
		# TODO: Technically the idle units will be updated once the command starts but that won't happen on this tick necessarily
		for occupied_unit in _tmp_units:
			_attacker_pool.erase(occupied_unit)
		
		if attacker_list:
			_currently_attacking_mapping[target_id] = attacker_list
	
	if _new_attacks:
		blackboard.currently_attacking = currently_attacking
	
func _on_command_finished(unit:Unit, command:StringName) -> void:
	if command == UnitBlackboard.Action.AttackUnit and is_instance_valid(unit) and unit.is_on_team(blackboard.team):
		print_debug("%s: unit=%s finished attacking" % [name, unit.name])
		
		var attacker_mapper: Dictionary[int,int] = blackboard.currently_attacking
		var attacker_id:int = unit.get_instance_id()

		var target_id:int = attacker_mapper.get(attacker_id, 0)		
		if target_id == 0:
			# FIXME: Slow path - Need to go through and remove from values
			# This is happening because the currently_attacking blackboard list has already been updated before the command finishes
			for other_target_id in _currently_attacking_mapping.keys():
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
			if not is_instance_id_valid(target_id):
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
