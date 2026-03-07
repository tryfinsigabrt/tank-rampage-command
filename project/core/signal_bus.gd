extends Node

@warning_ignore_start("unused_signal")

signal on_paused(paused:bool)

signal on_unit_deselected(unit:Unit)
signal on_unit_selected(unit: Unit)

signal on_unit_move_issued(unit: Unit, target_position: Vector3)
signal on_unit_move_canceled(unit: Unit, target_position: Vector3)
signal on_destination_reached(unit: Unit, target_position: Vector3)

signal on_unit_command_scheduled(unit:Unit, command:StringName, args:Dictionary[StringName,Variant])
signal on_unit_command_started(unit:Unit, command:StringName, args:Dictionary[StringName,Variant])
signal on_unit_command_finished(unit:Unit, command: StringName, args:Dictionary[StringName,Variant])

## Reported for damage on any collidable object
## collided objects with a Damageable group are delivered the events directly
signal on_any_damage(damage_parameters:DamageParameters)

signal on_unit_health_changed(unit:Unit, previous_health:float, current_health:float)
signal on_unit_damaged(unit:Unit, damage_parameters:DamageParameters)
signal on_unit_added(unit:Unit)
signal on_unit_killed(unit:Unit, damage_parameters:DamageParameters)


signal match_ready(match_obj:Match)
signal match_ended(match_obj:Match)
signal match_team_ready(match_team:MatchTeam)
signal match_team_eliminated(match_team:MatchTeam)

signal on_entered_world_boundaries(world_boundaries: WorldBoundaries, body: Node3D)
signal on_left_world_boundaries(world_boundaries: WorldBoundaries, body: Node3D)

signal on_utility_calculation(id:StringName, team:int, options:Array[UtilityAIOption], chosen_option:UtilityAIOption)
signal on_utility_calculation_complete(id:StringName, team:int)

@warning_ignore_restore("unused_signal")

func register_unit(unit:Unit) -> void:
	unit.died.connect(func(damage_params):
		on_unit_killed.emit(unit, damage_params)
	)
	unit.damaged.connect(func(damage_params):
		on_unit_damaged.emit(unit, damage_params)
	)
	var health_stat:HealthStat = Groups.get_children_with_type(unit, HealthStat, true).front()
	if health_stat:
		health_stat.health_changed.connect(func(previous_health, current_health):
			on_unit_health_changed.emit(unit, previous_health, current_health)
		)
	
	unit.on_left_world_boundaries.connect(func(world_boundaries: WorldBoundaries):
		on_left_world_boundaries.emit(world_boundaries, unit)
	)
	
	unit.on_entered_world_boundaries.connect(func(world_boundaries: WorldBoundaries):
		on_entered_world_boundaries.emit(world_boundaries, unit)
	)
	
	on_unit_added.emit(unit)
	
