extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

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
	
	return candidate_scrap_fields.front()
	
