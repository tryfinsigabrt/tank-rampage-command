extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

# FIXME: Replace this with just storing a PackedInt64Array of ids in the blackboard itself and then use TeamUnits to get the actual unit which handles lifetime
# Alternatively can just use Godot instance_from_id

# ObjectIDs require full 64-bit int looking at source in object.h
var _monitored_attacking_priorities:PackedInt64Array
var _monitored_attacking:PackedInt64Array
var _monitored_idle:PackedInt64Array
var _monitored_exploring:PackedInt64Array

func _on_blackboard_on_exploring_units_changed() -> void:
	_refresh_monitors(blackboard.exploring_units, _monitored_exploring, _on_exploring_unit_destroyed)
	
func _on_blackboard_on_idle_units_changed() -> void:
	_refresh_monitors(blackboard.idle_units, _monitored_idle, _on_idle_unit_destroyed)
	
func _on_attacking_priorities_changed() -> void:
	_refresh_monitors(blackboard.attack_priorities, _monitored_attacking_priorities, _on_attacking_priority_unit_destroyed)
	
func _on_attacking_units_changed() -> void:
	_refresh_dictionary_monitors(blackboard.currently_attacking, _monitored_attacking, _on_attacking_unit_destroyed)

func _on_exploring_unit_destroyed(unit:Unit) -> void:
	_on_destroyed(unit, blackboard.exploring_units, func(updated):
		# Trigger signal
		blackboard.exploring_units = updated
	)
	
func _on_idle_unit_destroyed(unit:Unit) -> void:
	_on_destroyed(unit, blackboard.idle_units, func(updated):
		# Trigger signal
		blackboard.idle_units = updated
	)
	
func _on_attacking_priority_unit_destroyed(unit:Unit) -> void:
	_on_destroyed(unit, blackboard.attack_priorities, func(updated):
		# Trigger signal
		blackboard.attack_priorities = updated
	)
		
func _on_attacking_unit_destroyed(unit:Unit) -> void:
	_on_destroyed_dict(unit, blackboard.currently_attacking, func(updated):
		# Trigger signal
		blackboard.currently_attacking = updated
	)

func _on_destroyed(unit:Unit, blackboard_value:Array[Unit], updater:Callable) -> void:
	var orig_size := blackboard_value.size()
	blackboard_value.erase(unit)
	if blackboard_value.size() != orig_size:
		updater.call(blackboard_value)

func _on_destroyed_dict(unit:Unit, blackboard_value, updater:Callable) -> void:
	var orig_size:int = blackboard_value.size()
	blackboard_value.erase(unit.get_instance_id())
	if blackboard_value.size() != orig_size:
		updater.call(blackboard_value)
				
func _refresh_monitors(source: Array[Unit], id_list:PackedInt64Array, receiver:Callable) -> void:
	for unit in source:
		var unit_id:int = unit.get_instance_id()
		# Cannot use is_connected since we are binding a new callable that will always be unique
		# and easier to just track the ids
		if not unit_id in id_list:
			var callable:Callable = receiver.bind(unit).unbind(1)
			if not unit.died.is_connected(callable):
				unit.died.connect(callable)

	_set_monitored_units(source, id_list)
	
func _set_monitored_units(source:Array[Unit], id_list:PackedInt64Array):
	id_list.resize(source.size())
	for i in source.size():
		id_list[i] = source[i].get_instance_id()
		
func _refresh_dictionary_monitors(source, id_list:PackedInt64Array, receiver:Callable) -> void:
	for unit_id in source:
		var unit:Unit = instance_from_id(unit_id)
		if not unit:
			continue
		# Cannot use is_connected since we are binding a new callable that will always be unique
		# and easier to just track the ids
		if not unit_id in id_list:
			var callable:Callable = receiver.bind(unit).unbind(1)
			if not unit.died.is_connected(callable):
				unit.died.connect(callable)

	_set_monitored_dictionary_units(source, id_list)
	
func _set_monitored_dictionary_units(source:Dictionary, id_list:PackedInt64Array):
	id_list.clear()
	id_list.append_array(source.keys())
