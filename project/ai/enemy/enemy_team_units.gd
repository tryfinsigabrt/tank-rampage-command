class_name EnemyTeamUnits extends Node

var team:int

## Key is the instance id of the Unit
var units:Dictionary[int, UnitData] = {}

@onready var threat_scorer: ThreatScorer = $ThreatScorer

func has_unit_id(id:int) -> bool:
	return units.has(id)
	
func has_unit(unit:Unit) -> bool:
	return is_instance_valid(unit) and has_unit_id(unit.get_instance_id())
	
func get_unit(id:int) -> Unit:
	var unit:Unit = units.get(id)
	if unit and is_instance_valid(unit):
		return unit
	return null
	
func mark_all_not_visible() -> void:
	for unit in units.values():
		unit.visible = false

func get_all_visible_ids(out_ids:PackedInt64Array) -> void:
	for unit_id in units:
		if units[unit_id].visible:
			out_ids.push_back(unit_id)

func mark_known(unit:Unit) -> UnitData:
	var id:int = unit.get_instance_id()
	var unit_data:UnitData = units.get(id)
	if not unit_data:
		unit_data = UnitData.create(unit)
		unit.died.connect(_on_unit_deleted.bind(unit).unbind(1))
		units[id] = unit_data
	return unit_data
	
func _on_unit_deleted(unit: Unit) -> void:
	print_debug("%s: unit deleted: %s" % [name, unit])
	units.erase(unit.get_instance_id())
	
func mark_seen(unit:Unit) -> UnitData:
	var unit_data:UnitData = mark_known(unit)
	unit_data.visible = true
	unit_data.last_known_position = unit.global_position
	unit_data.last_seen_timestamp = GameManager.game_timer.time_seconds
	
	return unit_data

func get_closest_visible_unit(position:Vector3) -> UnitData:
	var closest:UnitData = null
	var closest_distance:float = 1e100
	
	for unit_data:UnitData in units.values():
		if unit_data.valid and unit_data.visible:
			var dist_sq:float =  unit_data.unit.global_position.distance_squared_to(position)
			if dist_sq < closest_distance:
				closest = unit_data
				closest_distance = dist_sq
	return closest
		
func get_visible_threat_units(position:Vector3) -> Array[UnitScore]:
	return threat_scorer.get_visible_threat_units(units.values(), position)
