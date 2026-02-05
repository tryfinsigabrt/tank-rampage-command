extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

var _monitored_attacking_priorities:PackedInt64Array
var _monitored_attacking:PackedInt64Array

func _on_attacking_priorities_changed() -> void:
	_refresh_monitors(blackboard.attack_priorities, _monitored_attacking_priorities, _on_attacking_priority_unit_destroyed)
	
func _on_attacking_units_changed() -> void:
	_refresh_monitors(blackboard.currently_attacking, _monitored_attacking, _on_attacking_unit_destroyed)

func _on_attacking_priority_unit_destroyed(unit:Unit) -> void:
	_on_destroyed(unit, blackboard.attack_priorities, func(updated):
		# Trigger signal
		blackboard.attack_priorities = updated
	)
		
func _on_attacking_unit_destroyed(unit:Unit) -> void:
	_on_destroyed(unit, blackboard.currently_attacking, func(updated):
		# Trigger signal
		blackboard.currently_attacking = updated
	)

func _on_destroyed(unit:Unit, blackboard_value:Array[Unit], updater:Callable) -> void:
	var orig_size := blackboard_value.size()
	blackboard_value.erase(unit)
	if blackboard_value.size() != orig_size:
		updater.call(blackboard_value)
		
func _refresh_monitors(source: Array[Unit], id_list:PackedInt64Array, receiver:Callable) -> void:
	for unit in source:
		var unit_id:int = unit.get_instance_id()
		# Cannot use is_connected since we are binding a new callable that will always be unique
		# and easier to just track the ids
		if not unit_id in id_list:
			unit.died.connect(receiver.bind(unit).unbind(1))

	_set_monitored_units(source, id_list)
	
func _set_monitored_units(source:Array[Unit], id_list:PackedInt64Array):
	id_list.resize(source.size())
	for i in source.size():
		id_list[i] = source[i].get_instance_id()
