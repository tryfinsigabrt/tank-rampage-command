class_name BaseLocationPrioritizer extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

## Temporary flag during testing
@export
var enable_assistance:bool

@export
var min_discovery_hold_strength:float = 10.0

@export
var ideal_enemy_army_hold_strength:float = 0.1

@export
var discovery_hold_duration:float = 30.0

@export
var secure_hold_duration:float = 120.0

@export
var min_secure_strength:float = 20.0

@export
var ideal_enemy_army_secure_fraction:float = 0.3

func _on_scrap_field_discovered(scrap_field:ScrapField) -> void:
	var fields:Array[EnemyTeamBlackboard.ScrapFieldData] = blackboard.active_scrap_fields
	var scrap_field_data := EnemyTeamBlackboard.ScrapFieldData.new(scrap_field)
	
	fields.push_back(scrap_field_data)
	
	# Re-evaluate after the resource is exhausted
	scrap_field.tree_exited.connect(func() -> void:
		fields.erase(scrap_field_data)
		blackboard.on_available_scrap_fields_changed.emit()
	)

	blackboard.on_available_scrap_fields_changed.emit()
	
	if enable_assistance:
		_watch_scrap_field.call_deferred(scrap_field_data)
	
func _on_scrap_field_visibility_changed(scrap_field:ScrapField, in_visible:bool) -> void:
	var fields:Array[EnemyTeamBlackboard.ScrapFieldData] = blackboard.active_scrap_fields
	var field_data := EnemyTeamBlackboard.ScrapFieldData.find_by_scrap_field_id(fields, scrap_field.get_instance_id())
	
	if not field_data:
		push_warning("%s: Could not find scrap field data for field=%s; in_visible=%s" % [name, scrap_field.name, in_visible])
		return
	
	# Refresh all data so that teams are locked when visibility immediately goes to false
	field_data.visible = in_visible
	field_data.refresh_teams()
	
	blackboard.on_available_scrap_fields_changed.emit()

func get_best_open_scrap_field() -> ScrapField:
	# Pick best open location that is further from a known enemy scrap field
	var candidate_scrap_fields: Array[EnemyTeamBlackboard.ScrapFieldData]
	var mined_scrap_fields: Array[EnemyTeamBlackboard.ScrapFieldData]
	var scrap_field_data := blackboard.active_scrap_fields
	
	var team:int = blackboard.team
	# Prefer visible scrap fields, if not visible then will need to dispatch units to make sure it is still viable
	# This can be done with a signal on blackboard
	for data in scrap_field_data:
		data.refresh_visible_data()
		if data.open:
			candidate_scrap_fields.push_back(data)
		elif team in data.teams:
			mined_scrap_fields.push_back(data)
	
	if not candidate_scrap_fields:
		return null
	
	# Score best distance
	# TODO: Consider buildings
	for data in candidate_scrap_fields:
		var min_dist:float = INF
		var candidate_loc:Vector3 = data.location
		for mined_data in mined_scrap_fields:
			var dist_sq:float = mined_data.location.distance_squared_to(candidate_loc)
			min_dist = minf(min_dist, dist_sq)
		data.dist_sq_closest_base = min_dist
		
	candidate_scrap_fields.sort_custom(func(a:EnemyTeamBlackboard.ScrapFieldData, b:EnemyTeamBlackboard.ScrapFieldData) -> bool:
		var first_visible:bool = a.visible
		var second_visible:bool = b.visible
		if first_visible and not second_visible:
			return true
		elif second_visible and not first_visible:
			return false
		# Sort by distance to nearest base
		return a.dist_sq_closest_base < b.dist_sq_closest_base
	)
	
	var best_id:int = candidate_scrap_fields.front().id
	return instance_from_id(best_id)
	
#region Scrap Field Assistance
func _watch_scrap_field(scrap_field:EnemyTeamBlackboard.ScrapFieldData) -> void:
	if not scrap_field.open:
		return
	 
	var strength:float = _get_ideal_strength(min_discovery_hold_strength, ideal_enemy_army_hold_strength)
	_issue_assistance(instance_from_id(scrap_field.id), strength, discovery_hold_duration)
	
func _issue_assistance(resource_or_asset:Node3D, strength:float, time:float) -> void:
	if not resource_or_asset:
		return
		
	var boundingSphere := Bounds.create_circumscribed_sphere(resource_or_asset.get_bounds())
	var dir:Vector2 = MathUtils.get_rand_vector2_dir()
	var location:Vector3 = Vector3(dir.x, 0.0, dir.y) * boundingSphere.radius * 2.0
	
	var assistance := EnemyTeamBlackboard.AssistanceRequest.new()
	assistance.requesting_party_id = resource_or_asset.get_instance_id()
	assistance.timestamp = GameManager.game_timer.time_seconds
	assistance.strength = strength
	assistance.location = location
	assistance.min_duration = time
	
	blackboard.assistance_requests.push_back(assistance)
	
func _get_ideal_strength(min_strength:float, enemy_fraction:float) -> float:
	var enemy_teams := blackboard.enemy_teams_info
	var total_strength:float = 0.0
	
	for team:EnemyTeamUnits in enemy_teams:
		var assets := team.assets
		for asset_id in assets:
			var asset_data:UnitData = assets[asset_id]
			if asset_data.valid:
				var unit:Unit = asset_data.asset as Unit
				if unit:
					total_strength += unit.strength()
	return maxf(min_strength, total_strength * enemy_fraction)
				
func _secure_base(building:Building, duration:float) -> void:
	if not enable_assistance:
		return
	
	var strength:float = _get_ideal_strength(min_secure_strength, ideal_enemy_army_secure_fraction)
	_issue_assistance(building, strength, duration)

func _on_enemy_building_create_action_on_building_complete(_context: BuildBuildingUtilityContext, building: Building) -> void:
	if not enable_assistance or building is not CommandCenter:
		return
	
	# TODO: Get construction building and read remaining build time
	_secure_base(building, secure_hold_duration)
	
#endregion
