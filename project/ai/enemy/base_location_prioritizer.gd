class_name BaseLocationPrioritizer extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

@export
var building_score_v_dist:Curve

@export
var unit_score_v_dist:Curve

@export
var sf_closest_base_center_score_v_dist:Curve

@export
var sf_last_visible_multiplier:Curve
	
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

func get_best_open_scrap_field() -> EnemyTeamBlackboard.ScrapFieldData:
	# Pick best open location that is further from a known enemy scrap field
	var candidate_scrap_fields: Array[EnemyTeamBlackboard.ScrapFieldData]
	var mined_scrap_fields: Array[EnemyTeamBlackboard.ScrapFieldData]
	var scrap_field_data := blackboard.active_scrap_fields
	
	var team:int = blackboard.team
	
	# Prefer visible scrap fields, if not visible then will need to dispatch units to make sure it is still viable
	for data in scrap_field_data:
		data.refresh_visible_data()
		if data.open and is_instance_id_valid(data.id):
			candidate_scrap_fields.push_back(data)
		elif team in data.teams:
			mined_scrap_fields.push_back(data)
	
	if not candidate_scrap_fields:
		return null
	
	var units:Array[Unit] = blackboard.team_info.units
	var buildings:Array[Building] = blackboard.team_info.buildings
	
	var curr_time:float = GameManager.game_timer.time_seconds
	
	for data in candidate_scrap_fields:
		var min_dist:float = 1e9
		var candidate_loc:Vector3 = data.location
		for mined_data in mined_scrap_fields:
			var dist_sq:float = mined_data.location.distance_to(candidate_loc)
			min_dist = minf(min_dist, dist_sq)
		data.dist_closest_base = min_dist
	
	# Score the candidates
	for data in candidate_scrap_fields:
		var location:Vector3 = data.location
		var unit_score:float = 0.0
		var building_score:float = 0.0
		
		for unit in units:
			var dist:float = unit.global_position.distance_to(location)
			var dist_score:float = unit_score_v_dist.sample_baked(dist)
			var score:float = dist_score * unit.strength() / 5.0
			unit_score += score
		for building in buildings:
			# Already counted with closest base component
			if building is CommandCenter:
				continue
			var dist:float = building.global_position.distance_to(location)
			var dist_score:float = building_score_v_dist.sample_baked(dist)
			var score:float = dist_score * 10.0
			building_score += score
		data.score = unit_score * 0.6 + building_score * 0.4
		#print("%s(%s) : unit_score=%.3f; building_score=%.3f" % [name, instance_from_id(data.id).name, unit_score, building_score])
	
	for data in candidate_scrap_fields:
		var base_score:float = sf_closest_base_center_score_v_dist.sample_baked(data.dist_closest_base)
		var total_score:float = data.score + base_score * 0.3
		var time_offset:float = 0.0 if data.visible else curr_time - data.last_visible_time
		var time_multiplier:float = sf_last_visible_multiplier.sample_baked(time_offset)
		total_score *= time_multiplier
		
		#print("%s(%s) : base_score=%.3f; time_mult=%.3f; total_score=%.3f" % 
		#	[name, instance_from_id(data.id).name, base_score, time_multiplier, total_score])

		data.score = total_score
		
	candidate_scrap_fields.sort_custom(func(a:EnemyTeamBlackboard.ScrapFieldData, b:EnemyTeamBlackboard.ScrapFieldData) -> bool:
		return a.score > b.score
	)
	
	return candidate_scrap_fields.front()
