@tool
extends ActionLeaf

# Mapping unit being attacked to who is attacking it
var _currently_attacking_mapping:Dictionary[int,PackedInt64Array] = {}

# Mapping who is attacking to the unit they are attacking
var _attacker_mapping:Dictionary[int, int] = {}

var _new_attacks:Array[Unit]
var _temp_ids:PackedInt64Array

var _blackboard:EnemyTeamBlackboard

func before_run(_actor: Node, in_blackboard: Blackboard) -> void:
	# Sync up all our data
	_clear()
	
	SignalBus.on_unit_command_finished.connect(_on_command_finished)
	
	var blackboard: EnemyTeamBlackboard = in_blackboard
	_blackboard = blackboard
	
func after_run(_actor: Node, _in_blackboard: Blackboard) -> void:
	_clear()
	
func _clear() -> void:
	_currently_attacking_mapping.clear()
	_attacker_mapping.clear()
	_new_attacks.clear()
	_temp_ids.clear()
	
	if SignalBus.on_unit_command_finished.is_connected(_on_command_finished):
		SignalBus.on_unit_command_finished.disconnect(_on_command_finished)

	
func tick(_actor: Node, in_blackboard: Blackboard) -> int:
	var blackboard: EnemyTeamBlackboard = in_blackboard
	
	var currently_attacking:Array[Unit] = blackboard.currently_attacking
	var attack_priorities:Array[Unit] = blackboard.attack_priorities
		
	# See if select new units to attack
	_new_attacks.clear()
	
	for unit in attack_priorities:
		if not unit.get_instance_id() in _currently_attacking_mapping:
			_new_attacks.push_back(unit)
	
	if not _new_attacks and not currently_attacking:
		push_warning("%s: Pre-condition failure: No units being attacked and no new priorities" % name)
		return FAILURE
	
	var available_units:Array[Unit] = _blackboard.idle_units
	
	if not _new_attacks or not available_units:
		# Nothing new to do - keep thrashing the enemy!
		return RUNNING

	# TODO: Simple strategy
	var units_per_enemy:int = ceili(float(_new_attacks.size()) / available_units.size())
	_temp_ids.clear()

	for new_target in _new_attacks:
		# See who's available
		var target_id:int = new_target.get_instance_id()
		
		var attacker_list:PackedInt64Array
		if target_id in _currently_attacking_mapping:
			attacker_list = _currently_attacking_mapping[target_id]
		else:
			_currently_attacking_mapping[target_id] = attacker_list

		var count:int = 0
		for attacker in available_units:
			attacker.get_or_add_actions().attack(new_target)
			var available_unit_id:int = attacker.get_instance_id()
			_temp_ids.push_back(available_unit_id)
			attacker_list.push_back(available_unit_id)
			count += 1
			if count >= units_per_enemy:
				break
			
		# TODO: Technically the idle units will be updated once the command starts but that won't happen on this tick necessarily
		for occupied_unit in available_units:
			available_units.erase(occupied_unit)
		_temp_ids.clear()
		_currently_attacking_mapping[target_id] = attacker_list
	
	if _new_attacks:
		var _currently_attacking = blackboard.currently_attacking
		_currently_attacking.append_array(_new_attacks)
		blackboard.currently_attacking = _currently_attacking
	return RUNNING
	
	# TODO: SUCCESS condition?
	
func _on_command_finished(unit:Unit, command:StringName) -> void:
	if command == UnitBlackboard.Action.AttackUnit:
		var id:int = unit.get_instance_id()
		_attacker_mapping.erase(id)
		_blackboard.currently_attacking.erase(unit)
		# FIXME: Need a way to retrieve the target that was being attacked - it needs to be part of the signal so we can erase ourselves from _currently_attacknig_mapping
