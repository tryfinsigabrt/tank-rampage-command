class_name EnemyTeamBlackboard extends Blackboard

@warning_ignore("unused_signal")
signal on_unit_visibility_changed

signal on_attacking_units_changed
signal on_attacking_priorities_changed
signal on_avoidance_enemies_changed
signal on_idle_units_changed
signal on_exploring_units_changed

@warning_ignore("unused_signal")
signal on_buildings_under_attack_changed

@warning_ignore("unused_signal")
signal on_available_resources_changed

@warning_ignore("unused_signal")
signal on_available_scrap_fields_changed

@warning_ignore("unused_signal")
signal on_control_point_discovered(control_point:ControlPoint)

@warning_ignore("unused_signal")
signal on_defense_units_updated

signal match_team_set
 
class Keys:
	const enemy_teams_info:StringName = &"enemy_teams_info"
	const team_info:String = &"team_info"
	const focus_position:StringName = &"focus_position"
	const team:StringName = &"team"
	const match_team:StringName = &"match_team"
	const attack_priorities:StringName = &"attack_priorities"
	const avoidance_enemies:String = &"avoidance_enemies"
	# TODO: Should probably group these by the unit action to make it more extensible and less brittle
	const currently_attacking:StringName = &"currently_attacking"
	const idle_units:StringName = &"idle_units"
	const exploring_units:StringName = &"exploring_units"
	const explore_heading_bias:StringName = &"explore_heading_bias"
	const active_resources:StringName = &"active_resources"
	const active_scrap_fields:StringName = &"active_scrap_fields"
	const assigned_resources:StringName = &"assigned_resources"
	const threats:StringName = &"threats"
	const resource_calculation_cache:StringName = &"resource_calc_cache"
	const control_points:StringName = &"control_points"
	const control_point_priorities:StringName = &"control_point_priorities"
	const buildings_under_attack:StringName = &"bldgs_under_attack"
	const base_defend_units:StringName = &"base_defend_units"
	
class ScrapFieldData:
	var id:int
	var visible:bool:
		set(value):
			visible = value
			if value:
				last_visible_time = GameManager.game_timer.time_seconds
	var last_visible_time:float
	var teams:PackedInt32Array
	
	## Assuming when initialize it is was freshly discovered and visible
	func _init(scrap_field:ScrapField) -> void:
		id = scrap_field.get_instance_id()
		# Setters triggered in init, so this will set the first visible timestamp
		visible = true
		teams = scrap_field.get_mining_teams()
	
	func refresh_visible_data() -> void:
		if not visible:
			return
		refresh_teams()
		
	func refresh_teams() -> void:
		var field:ScrapField = 	instance_from_id(id)
		if field:
			teams = field.get_mining_teams()
			
	static func find_by_scrap_field_id(values:Array[ScrapFieldData], field_id:int) -> ScrapFieldData:
		for data in values:
			if data.id == field_id:
				return data
		return null
		
var enemy_teams_info:EnemyTeams:
	get:
		return get_value(Keys.enemy_teams_info)
	set(value):
		set_value(Keys.enemy_teams_info, value)

var base_defend_units:Dictionary[int,int]:
	get:
		if has_value(Keys.base_defend_units):
			return get_value(Keys.base_defend_units)
		else:
			var empty: Dictionary[int,int]
			base_defend_units = empty
			return empty
	set(value):
		set_value(Keys.base_defend_units, value)
		
var currently_attacking:Dictionary[int, int]:
	get:
		return get_value(Keys.currently_attacking, {} as Dictionary[int, int])
	set(value):
		#var existing := currently_attacking
		set_value(Keys.currently_attacking, value)
		#if value != existing:
		on_attacking_units_changed.emit()
		
var attack_priorities:Array[AttackPriority]:
	get:
		return get_value(Keys.attack_priorities, [] as Array[AttackPriority])
	set(value):
		var existing := attack_priorities
		set_value(Keys.attack_priorities, value)
		if value != existing:
			on_attacking_priorities_changed.emit()

var avoidance_enemies:Array[Unit]:
	get:
		return get_value(Keys.avoidance_enemies, [] as Array[Unit])
	set(value):
		var existing := avoidance_enemies
		set_value(Keys.avoidance_enemies, value)
		if value != existing:
			# Clear out heading bias calculations
			explore_heading_bias = {}
			on_avoidance_enemies_changed.emit()
				
var idle_units:Array[Unit]:
	get:
		return get_value(Keys.idle_units, [] as Array[Unit])
	set(value):
		#var existing := idle_units
		set_value(Keys.idle_units, value)
		#if value != existing:
		on_idle_units_changed.emit()

var exploring_units:Array[Unit]:
	get:
		return get_value(Keys.exploring_units, [] as Array[Unit])
	set(value):
		var existing := exploring_units
		set_value(Keys.exploring_units, value)
		if value != existing:
			on_exploring_units_changed.emit()

var buildings_under_attack:Array[Building]:
	get:
		if has_value(Keys.buildings_under_attack):
			return get_value(Keys.buildings_under_attack)
		else:
			var empty:Array[Building]
			buildings_under_attack = empty
			return empty
	set(value):
		set_value(Keys.buildings_under_attack, value)
			
var team_info:TeamUnits:
	get:
		return get_value(Keys.team_info)
	set(value):
		set_value(Keys.team_info, value)
		
func get_enemy_team_info(in_team:int) -> EnemyTeamUnits:
	var enemy_teams:EnemyTeams = enemy_teams_info
	if enemy_teams:
		return enemy_teams.get_team(in_team)
	return null

var team:int:
	get:
		return get_value(Keys.team, 0)
	set(value):
		set_value(Keys.team, value)

var match_team:MatchTeam:
	get:
		var value: MatchTeam = get_value(Keys.match_team)
		assert(value, "%s: Match Team is null!" % name)
		return value
	set(value):
		set_value(Keys.match_team, value)
		match_team_set.emit(value)
	
var focus_position:Vector3:
	get:
		return get_value(Keys.focus_position, Vector3.ZERO)
	set(value):
		set_value(Keys.focus_position, value)

var explore_heading_bias:Dictionary[int,Vector3]:
	get:
		return get_value(Keys.explore_heading_bias, {} as Dictionary[int,Vector3])
	set(value):
		set_value(Keys.explore_heading_bias, value)

var visible_enemy_count:int:
	get:
		return attack_priorities.size() + avoidance_enemies.size()
		
var active_resources:PackedInt64Array:
	get:
		if not has_value(Keys.active_resources):
			active_resources = PackedInt64Array()
		return get_value(Keys.active_resources)
	set(value):
		set_value(Keys.active_resources, value)

var active_scrap_fields:Array[ScrapFieldData]:
	get:
		if not has_value(Keys.active_scrap_fields):
			active_scrap_fields = []
		return get_value(Keys.active_scrap_fields)
	set(value):
		set_value(Keys.active_scrap_fields, value)
		
var threats:Array[EnemyThreatContext]:
	get:
		if not has_value(Keys.threats):
			threats = [] as Array[EnemyThreatContext]
		return get_value(Keys.threats)
	set(value):
		set_value(Keys.threats, value)

var resource_calculation_cache:Dictionary[int, Dictionary]:
	get:
		if not has_value(Keys.resource_calculation_cache):
			resource_calculation_cache = {} as Dictionary[int, Dictionary]
		return get_value(Keys.resource_calculation_cache)
	set(value):
		set_value(Keys.resource_calculation_cache, value)
		
var assigned_resources:PackedInt64Array:
	get:
		if not has_value(Keys.assigned_resources):
			assigned_resources = PackedInt64Array()
		return get_value(Keys.assigned_resources)
	set(value):
		set_value(Keys.assigned_resources, value)

var control_points:Array[ControlPoint]:
	get:
		if not has_value(Keys.control_points):
			control_points = [] as Array[ControlPoint]
		return get_value(Keys.control_points)
	set(value):
		set_value(Keys.control_points, value)

var control_point_priorities:Array[ControlPoint]:
	get:
		if not has_value(Keys.control_point_priorities):
			control_point_priorities = [] as Array[ControlPoint]
		return get_value(Keys.control_point_priorities)
	set(value):
		set_value(Keys.control_point_priorities, value)
