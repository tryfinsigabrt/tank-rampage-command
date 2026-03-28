class_name MatchTeam extends Node3D

@export
var team:int

var _units:Dictionary[int, Unit] = {}
var _buildings:Dictionary[int, Building] = {}

var units:Array[Unit]:
	get: return _units.values()

var buildings: Array[Building]:
	get: return _buildings.values()
	
var active:bool:
	get: return _units or _buildings

func _ready() -> void:
	var starting_units:Array[Node] = Groups.get_children_in_group(self, Groups.Unit)
	for node in starting_units:
		var unit:Unit = node as Unit
		if not unit:
			push_warning("%s: Found node=%s labeled in group 'Unit' but is not a Unit type" % [name, node.name])
			continue
		unit.team = team
		HealthStat.connect_died_signal(unit, _on_unit_destroyed.bind(unit))
		_units[unit.get_instance_id()] = unit
		
	var starting_buildings:Array[Node] = Groups.get_children_in_group(self, Groups.Building)
	for node in starting_buildings:
		var building:Building = node as Building
		if not building:
			push_warning("%s: Found node=%s labeled in group 'Building' but is not a Building type" % [name, node.name])
			continue
		building.team = team
		HealthStat.connect_died_signal(building, _on_building_destroyed.bind(building))
		_buildings[building.get_instance_id()] = building
		
	await get_tree().process_frame
	SignalBus.match_team_ready.emit(self)
	
func _on_unit_destroyed(unit:Unit) -> void:
	print_debug("%s: unit=%s destroyed" % [name, unit.name])
	
	if not _units.erase(unit.get_instance_id()):
		return
	
	@warning_ignore("missing_await")
	_check_defeated()
	
func _on_building_destroyed(building:Building) -> void:
	print_debug("%s: building=%s destroyed" % [name, building.name])
	
	if not _buildings.erase(building.get_instance_id()):
		return

	@warning_ignore("missing_await")
	_check_defeated()

func _check_defeated() -> void:
	if not active:
		await get_tree().process_frame
		SignalBus.match_team_eliminated.emit(self)
