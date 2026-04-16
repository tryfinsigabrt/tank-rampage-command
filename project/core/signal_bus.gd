extends Node

@warning_ignore_start("unused_signal")

signal on_paused(paused:bool)

signal on_unit_deselected(unit:Unit)
signal on_unit_selected(unit: Unit)

signal on_building_deselected(building:Building)
signal on_building_selected(building:Building)

signal on_unit_move_issued(unit: Unit, target_position: Vector3)
signal on_unit_move_canceled(unit: Unit, target_position: Vector3)
signal on_destination_reached(unit: Unit, target_position: Vector3)

signal on_unit_command_scheduled(unit:Unit, command:StringName, args:Dictionary[StringName,Variant])
signal on_unit_command_started(unit:Unit, command:StringName, args:Dictionary[StringName,Variant])
signal on_unit_command_finished(unit:Unit, command: StringName, args:Dictionary[StringName,Variant])

signal on_order_manager_command_issued(command: StringName)

## Reported for damage on any collidable object
## collided objects with a Damageable group are delivered the events directly
signal on_any_damage(damage_parameters:DamageParameters)

signal on_unit_health_changed(unit:Unit, previous_health:float, current_health:float)
signal on_unit_damaged(unit:Unit, damage_parameters:DamageParameters)
signal on_unit_added(unit:Unit)
signal on_unit_killed(unit:Unit, damage_parameters:DamageParameters)

signal on_team_asset_added(asset:Node3D)
signal on_team_asset_destroyed(asset:Node3D, damage_parameters:DamageParameters)
signal on_team_asset_damaged(asset:Node3D, damage_parameters:DamageParameters)

signal on_team_asset_changed_teams(asset:Node3D, previous_team:int, new_team:int)

signal on_control_point_captured(new_owning_team:int, control_point:ControlPoint)
signal on_control_point_neutralized(previous_owning_team:int, control_point:ControlPoint)

signal match_ready(match_obj:Match)
signal match_ended(match_obj:Match)
signal match_team_ready(match_team:MatchTeam)
signal match_team_eliminated(match_team:MatchTeam)

signal on_entered_world_boundaries(world_boundaries: WorldBoundaries, body: Node3D)
signal on_left_world_boundaries(world_boundaries: WorldBoundaries, body: Node3D)

signal on_utility_calculation(id:StringName, team:int, options:Array[UtilityAIOption], chosen_option:UtilityAIOption)
signal on_utility_calculation_complete(id:StringName, team:int)

signal on_scrap_field_exhausted(field:ScrapField, command_center:CommandCenter)
signal on_scrap_field_mined(field:ScrapField, command_center:CommandCenter, count:int)

@warning_ignore_restore("unused_signal")

func register_control_point(control_point:ControlPoint) -> void:
	_register_asset(control_point)
	# TODO: Need to trigger team asset added/destroyed when gain or lose ownership
	
func register_building(building:Building) -> void:
	_register_asset(building)

func register_structure(structure:DefensiveStructure) -> void:
	_register_asset(structure)
	
func _register_asset(asset:Node3D) -> void:
	var health_comp:HealthStat = Components.get_component(Components.Health, asset, false)
	if health_comp:
		health_comp.died.connect(func(damage_params: DamageParameters) -> void:
			on_team_asset_destroyed.emit(asset, damage_params)
		)
		health_comp.took_damage.connect(func(damage_params: DamageParameters) -> void:
			on_team_asset_damaged.emit(asset, damage_params)
		)
	
	on_team_asset_added.emit(asset)
	
func register_unit(unit:Unit) -> void:
	unit.died.connect(func(damage_params: DamageParameters) -> void:
		on_unit_killed.emit(unit, damage_params)
		on_team_asset_destroyed.emit(unit, damage_params)
	)
	unit.damaged.connect(func(damage_params: DamageParameters) -> void:
		on_unit_damaged.emit(unit, damage_params)
		on_team_asset_damaged.emit(unit,damage_params)
	)
	var health_stat:HealthStat = Components.get_component(Components.Health, unit)
	if health_stat:
		health_stat.health_changed.connect(func(previous_health: float, current_health: float) -> void:
			on_unit_health_changed.emit(unit, previous_health, current_health)
		)
	
	unit.on_left_world_boundaries.connect(func(world_boundaries: WorldBoundaries) -> void:
		on_left_world_boundaries.emit(world_boundaries, unit)
	)
	
	unit.on_entered_world_boundaries.connect(func(world_boundaries: WorldBoundaries) -> void:
		on_entered_world_boundaries.emit(world_boundaries, unit)
	)
	
	on_unit_added.emit(unit)
	on_team_asset_added.emit(unit)
	
