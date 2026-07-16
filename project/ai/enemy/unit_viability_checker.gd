extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

# FIXME: Replace this with just storing a PackedInt64Array of ids in the blackboard itself and then use TeamUnits to get the actual unit which handles lifetime
# Alternatively can just use Godot instance_from_id

# ObjectIDs require full 64-bit int looking at source in object.h
var _monitored_attacking_priorities:PackedInt64Array
var _monitored_attacking:Dictionary[int,bool]
var _monitored_idle:PackedInt64Array
var _monitored_exploring:PackedInt64Array
var _monitored_avoidance_enemies:PackedInt64Array

func _on_blackboard_on_exploring_units_changed() -> void:
	_refresh_monitors(blackboard.exploring_units, _monitored_exploring, _on_exploring_unit_destroyed)
	
func _on_blackboard_on_idle_units_changed() -> void:
	_refresh_monitors(blackboard.idle_units, _monitored_idle, _on_idle_unit_destroyed)
	
func _on_attacking_priorities_changed() -> void:
	_refresh_monitors(blackboard.attack_priorities, _monitored_attacking_priorities, _on_attacking_priority_entry_destroyed,
		func(value:AttackPriority) -> Node3D:
			return value.target
	)
	
func _on_attacking_units_changed() -> void:
	_refresh_dictionary_monitors(blackboard.currently_attacking, _monitored_attacking, _on_attacking_unit_destroyed)

func _on_avoidance_enemies_changed() -> void:
	_refresh_monitors(blackboard.avoidance_enemies, _monitored_avoidance_enemies, _on_avoidance_enemy_destroyed)
	
func _on_exploring_unit_destroyed(unit:Unit) -> void:
	_on_destroyed(unit, blackboard.exploring_units, func(updated: Array[Unit]) -> void:
		# Trigger signal
		blackboard.exploring_units = updated
	)
	
func _on_idle_unit_destroyed(unit:Unit) -> void:
	_on_destroyed(unit, blackboard.idle_units, func(updated: Array[Unit]) -> void:
		# Trigger signal
		blackboard.idle_units = updated
	)
	
func _on_attacking_priority_entry_destroyed(entry:AttackPriority) -> void:
	var values := blackboard.attack_priorities
	_on_destroyed(entry, values, func(updated: Array) -> void:
		# Trigger signal
		blackboard.attack_priorities = updated
	,
	func() -> int:
		var target:Node3D = entry.target
		for i in values.size():
			var value:AttackPriority = values[i]
			if target == value.target:
				return i
		return -1
	)
	
func _on_avoidance_enemy_destroyed(unit:Unit) -> void:
	_on_destroyed(unit, blackboard.avoidance_enemies, func(updated: Array[Node3D]) -> void:
		# Trigger signal
		blackboard.avoidance_enemies = updated
	)
		
func _on_attacking_unit_destroyed(source_unit_id:int, target_unit_id:int, destroyed_param_index:int) -> void:
	_on_destroyed_dict(source_unit_id, target_unit_id, destroyed_param_index, blackboard.currently_attacking, func(updated: Dictionary[int,int]) -> void:
		# Trigger signal
		blackboard.currently_attacking = updated
	)
	
func _on_destroyed(value:Variant, blackboard_value:Array, updater:Callable, blackboard_finder:Callable = Callable()) -> void:
	var orig_size := blackboard_value.size()
	if blackboard_finder:
		var index:int = blackboard_finder.call()
		if index != -1:
			blackboard_value.remove_at(index)
	else:
		blackboard_value.erase(value)
	if blackboard_value.size() != orig_size:
		updater.call(blackboard_value)

func _on_destroyed_dict_keys(unit:Unit, blackboard_value: Array, updater:Callable) -> void:
	var orig_size:int = blackboard_value.size()
	blackboard_value.erase(unit.get_instance_id())
	if blackboard_value.size() != orig_size:
		updater.call(blackboard_value)
	
func _on_destroyed_dict(source_id:int, target_id:int, destroyed_param_index:int, blackboard_value: Dictionary[int,int], updater:Callable) -> void:
	var orig_size := blackboard_value.size()
	if destroyed_param_index == 0:
		blackboard_value.erase(source_id)
	else: #target
		# Need to remove all other sources that mapped that target
		blackboard_value.erase(source_id)
		
		for other_source:int in blackboard_value.keys():
			var other_target: int = blackboard_value[other_source]
			if other_target == target_id:
				blackboard_value.erase(other_source)
				
	if blackboard_value.size() != orig_size:
		updater.call(blackboard_value)
		
func _refresh_monitors(source: Array, id_list:PackedInt64Array, receiver:Callable, unit_extractor:Callable = Callable()) -> void:
	for value:Variant in source:
		if not is_instance_valid(value):
			continue
		var asset:Node3D = unit_extractor.call(value) if unit_extractor else value
		if not is_instance_valid(asset):
			continue
		var asset_id:int = asset.get_instance_id()
		# Cannot use is_connected since we are binding a new callable that will always be unique
		# and easier to just track the ids
		if not asset_id in id_list:
			var callable:Callable = receiver.bind(value)
			HealthStat.connect_died_signal(asset, callable, false)

	_set_monitored_units(source, id_list, unit_extractor)
	
func _set_monitored_units(source:Array, id_list:PackedInt64Array, unit_extractor:Callable = Callable()) -> void:
	id_list.resize(source.size())
	
	var count:int = 0
	for i in source.size():
		var value:Variant = source[i]
		if not is_instance_valid(value):
			continue
		var unit:Unit = unit_extractor.call(source[i]) if unit_extractor else value
		if is_instance_valid(unit):
			id_list[count] = unit.get_instance_id()
			count += 1
	id_list.resize(count)
		
func _refresh_dictionary_keys_monitors(source: Dictionary, id_list:PackedInt64Array, receiver:Callable) -> void:
	for unit_id:int in source:
		var unit:Unit = instance_from_id(unit_id)
		if not unit:
			continue
		# Cannot use is_connected since we are binding a new callable that will always be unique
		# and easier to just track the ids
		if not unit_id in id_list:
			var callable:Callable = receiver.bind(unit).unbind(1)
			if not unit.died.is_connected(callable):
				unit.died.connect(callable)

	_set_monitored_dictionary_keys_units(source, id_list)
	
func _set_monitored_dictionary_keys_units(source:Dictionary, id_list:PackedInt64Array) -> void:
	id_list.clear()
	id_list.append_array(source.keys())

func _refresh_dictionary_monitors(source:Dictionary[int,int], ids:Dictionary[int,bool], receiver:Callable) -> void:
	for source_id in source:
		var target_id := source[source_id]
		var source_unit:Unit = instance_from_id(source_id)
		var target_unit:Unit = instance_from_id(target_id)

		if not source_id in ids and source_unit and target_unit:
			# Unbind the original damage parameters
			var source_callable:Callable =  receiver.bind(source_id, target_id, 0).unbind(1)
			var target_callable:Callable =  receiver.bind(source_id, target_id, 1).unbind(1)
			
			# If either unit is destroyed (source or target), trigger a callable
			if not source_unit.died.is_connected(source_callable):
				source_unit.died.connect(source_callable)
			if not target_unit.died.is_connected(target_callable):
				target_unit.died.connect(target_callable)

	_set_monitored_dictionary_units(source, ids)

func _set_monitored_dictionary_units(source:Dictionary[int,int], ids:Dictionary[int,bool]) -> void:
	ids.clear()
	# Monitoring keys and values
	for key in source:
		ids[key] = true
		ids[source[key]] = true
