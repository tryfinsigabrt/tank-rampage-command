class_name EnemyTeamUnits extends Node

var team:int

## Key is the instance id of the Unit
var units:Dictionary[int, UnitData] = {}

func mark_all_not_visible() -> void:
	for unit in units.values():
		unit.visible = false
		
func mark_known(unit:Unit) -> UnitData:
	var id:int = unit.get_instance_id()
	var unit_data:UnitData = units.get(id)
	if not unit_data:
		unit_data = UnitData.create(unit)
		units[id] = unit_data
	return unit_data
	
func mark_seen(unit:Unit) -> UnitData:
	var unit_data:UnitData = mark_known(unit)
	unit_data.visible = true
	unit_data.last_known_position = unit.global_position
	unit_data.last_seen_timestamp = GameManager.game_timer.elapsed_time
	
	return unit_data
