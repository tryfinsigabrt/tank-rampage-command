class_name MatchTeam extends Node3D

@export
var team:int

@onready var asset_container: Node3D = $Assets

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
		_add_unit(unit)
		
	var starting_buildings:Array[Node] = Groups.get_children_in_group(self, Groups.Building)
	for node in starting_buildings:
		var building:Building = node as Building
		if not building:
			push_warning("%s: Found node=%s labeled in group 'Building' but is not a Building type" % [name, node.name])
			continue
		_add_building(building)
		
	await get_tree().process_frame
	SignalBus.match_team_ready.emit(self)
	
	# Add new units and buildings as they are built
	SignalBus.on_team_asset_added.connect(_on_asset_added)

func _add_unit(unit:Unit) -> void:
	unit.team = team
	HealthStat.connect_died_signal(unit, _on_unit_destroyed.bind(unit))
	_units[unit.get_instance_id()] = unit
		
func _add_building(building:Building) -> void:
	building.team = team
	HealthStat.connect_died_signal(building, _on_building_destroyed.bind(building))
	_buildings[building.get_instance_id()] = building
		
func _on_asset_added(asset:Node3D) -> void:
	if not asset.is_in_group(Groups.TeamAsset):
		push_warning("%s: _on_asset_added - attempted to add non-TeamAsset %s" % [name, asset.name])
		return
	var team_component:TeamComponent = Components.get_component(Components.Team, asset)
	if not team_component:
		push_warning("%s: _on_asset_added - asset=%s has no TeamComponent" % [name, asset.name])
		return
		
	if not team_component.is_on_team(team):
		return
		
	if asset is Unit:
		_add_unit(asset)
	elif asset is Building:
		_add_unit(asset)
		
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
