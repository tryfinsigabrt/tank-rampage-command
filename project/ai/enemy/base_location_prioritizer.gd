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
