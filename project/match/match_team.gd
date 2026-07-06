class_name MatchTeam extends Node3D

@export
var team:int

var is_player_team:bool

signal match_team_ready
signal units_changed
signal buildings_changed
signal structures_changed

var is_match_ready:bool

@export
var resources:TeamResources:
	set(value):
		resources = value
		if is_node_ready():
			team_resources.resources = resources

@export
var config:MatchTeamConfig

@onready var asset_container: Node3D = $Assets
@onready var team_resources:TeamResourceComponent = %TeamResourceComponent
@onready var team_visibility_component: TeamVisibilityComponent = %TeamVisibilityComponent
@onready var inventory_component: InventoryComponent = %InventoryComponent
@onready var stat_tracker: MatchTeamStatTracker = %StatTracker

var _units:Dictionary[int, Unit] = {}
var _buildings:Dictionary[int, Building] = {}
var _structures:Dictionary[int, DefensiveStructure] = {}

const IS_PREDEPLOYED_KEY:StringName = "Predeployed"

var units:Array[Unit]:
	get: return _units.values()
	
var unit_count:int:
	get: return _units.size()

var buildings: Array[Building]:
	get: return _buildings.values()

var building_count:int:
	get: return _buildings.size()
	
var structures: Array[DefensiveStructure]:
	get: return _structures.values()
	
var structure_count:int:
	get: return _structures.size()
	
var assets: Array[Node3D]:
	get:
		var _assets:Array[Node3D]
		_assets.resize(_units.size() + _buildings.size() + _structures.size())
		
		var cnt:int = 0
		for id in _units:
			_assets[cnt] = _units[id]
			cnt += 1
		for id in _buildings:
			_assets[cnt] = _buildings[id]
			cnt += 1
		for id in _structures:
			_assets[cnt] = _structures[id]
			cnt += 1
			
		return _assets

var total_asset_count:int:
	get: return _units.size() + _buildings.size() + _structures.size()


var scrap_per_minute:float:
	get:
		var total := 0.0
		for building in buildings:
			if building == null or not is_instance_valid(building):
				continue
			var mining_component := MiningComponent.get_component(building, false)
			if mining_component == null:
				continue
			total += mining_component.scrap_per_minute
		return total
	
var _active:bool = true
		
var active:bool:
	get: return _active
	
func _ready() -> void:
	team_visibility_component.team = team
	
	if not resources:
		resources = TeamResources.new()
	# Need to duplicate as these resources are modified during gameplay
	else:
		resources = resources.duplicate_deep()
	resources.initialize()
	
	if config and config.construction:
		team_resources.default_costs = config.construction
	team_resources.resources = resources
	
	var starting_units:Array[Node] = Groups.get_children_in_group(self, Groups.Unit)
	for node in starting_units:
		var unit:Unit = node as Unit
		if not unit:
			push_warning("%s: Found node=%s labeled in group 'Unit' but is not a Unit type" % [name, node.name])
			continue
		unit.set_meta(IS_PREDEPLOYED_KEY, true)
		_disable_non_player_predeployed_visible_nodes(unit)
		_add_unit(unit)
		
	var starting_buildings:Array[Node] = Groups.get_children_in_group(self, Groups.Building)
	for node in starting_buildings:
		var building:Building = node as Building
		if not building:
			push_warning("%s: Found node=%s labeled in group 'Building' but is not a Building type" % [name, node.name])
			continue
		building.set_meta(IS_PREDEPLOYED_KEY, true)
		_disable_non_player_predeployed_visible_nodes(building)
		_add_building(building)
		
	var starting_structures:Array[Node] = Groups.get_children_in_group(self, Groups.Structure)
	for node in starting_structures:
		var structure:DefensiveStructure = node as DefensiveStructure
		if not structure:
			push_warning("%s: Found node=%s labeled in group 'Stucture' but is not a DefensiveStructure type" % [name, node.name])
			continue
		structure.set_meta(IS_PREDEPLOYED_KEY, true)
		_disable_non_player_predeployed_visible_nodes(structure)
		_add_structure(structure)
		
	await get_tree().process_frame
	
	team_resources.team = team
	team_resources.initialize()
	
	# Add new units and buildings as they are built
	SignalBus.on_team_asset_added.connect(_on_asset_added)
	
	_match_team_ready()

func _match_team_ready() -> void:
	if not Groups.get_children_in_group(self, Groups.MatchTeamEliminationCondition, true):
		push_warning("%s: MatchTeam has no elimination condition - using default" % name)
		add_child(DefaultMatchTeamElimination.new())
		
	SignalBus.match_team_ready.emit(self)
	match_team_ready.emit()
	is_match_ready = true
	
func wait_for_ready() -> void:
	if is_match_ready:
		return
	await match_team_ready
	
func assign_to_team(asset:Node3D) -> bool:
	var team_assigned:bool = false
	if "team" in asset:
		asset.team = team
		team_assigned = true
	asset_container.add_child(asset)
	if not team_assigned:
		var team_component:TeamComponent = TeamComponent.get_component(asset, false)
		if team_component:
			team_component.team = team
			team_assigned = true
	
	return team_assigned

func eliminate() -> void:
	if _active:
		_active = false
		await get_tree().process_frame
		SignalBus.match_team_eliminated.emit(self)
		
func _add_unit(unit:Unit) -> void:
	unit.team = team
	HealthStat.connect_died_signal(unit, _on_unit_destroyed.bind(unit))
	_units[unit.get_instance_id()] = unit
	
	team_resources.spend_resources(unit)
	
	units_changed.emit()
	
func _add_building(building:Building) -> void:
	building.team = team
	HealthStat.connect_died_signal(building, _on_building_destroyed.bind(building))
	_buildings[building.get_instance_id()] = building
	
	team_resources.spend_resources(building)
	
	buildings_changed.emit()
	
func _add_structure(structure:DefensiveStructure) -> void:
	structure.team = team
	HealthStat.connect_died_signal(structure, _on_structure_destroyed.bind(structure))
	_structures[structure.get_instance_id()] = structure
	
	team_resources.spend_resources(structure)
	
	structures_changed.emit()
	
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

	if not is_player_team:
		_disable_non_player_visible_nodes(asset)	
				
	if asset is Unit:
		_add_unit(asset)
	elif asset is Building:
		_add_building(asset)
	elif asset is DefensiveStructure:
		_add_structure(asset)

func _disable_non_player_predeployed_visible_nodes(asset:Node3D) -> void:
	# Have to take the slow path as the player team may not be set yet
	if GameManager.is_owned_by_player(asset):
		return
	_disable_non_player_visible_nodes(asset)
	
func _disable_non_player_visible_nodes(asset:Node3D) -> void:
	# Free any team-visible only nodes like the BuildQueueDisplay
	for node in Groups.get_children_in_group(asset, Groups.TeamVisible):
		node.queue_free()

func _on_unit_destroyed(unit:Unit) -> void:
	print_debug("%s: unit=%s destroyed" % [name, unit.name])
	
	if not _units.erase(unit.get_instance_id()):
		return
	
	team_resources.refund_unit_cost(unit)
	
	units_changed.emit()
	
func _on_building_destroyed(building:Building) -> void:
	print_debug("%s: building=%s destroyed" % [name, building.name])
	
	if not _buildings.erase(building.get_instance_id()):
		return

	buildings_changed.emit()
	
func _on_structure_destroyed(structure:DefensiveStructure) -> void:
	print_debug("%s: structure=%s destroyed" % [name, structure.name])
	
	if not _structures.erase(structure.get_instance_id()):
		return

	structures_changed.emit()

#region Iterator
class It:
	var index:int
	var buildings_start:int
	var structures_start:int
	var size:int
	var values:Array
	
func _iter_init(arg: Array) -> bool:
	var num_units:int = _units.size()
	var num_buildings:int = _buildings.size()
	var num_structures:int = _structures.size()
		
	var it := It.new()
	it.buildings_start = num_units
	it.structures_start = num_units + num_buildings
	it.size = it.structures_start + num_structures
	
	arg[0] = it
	
	return it.size > 0

func _iter_next(arg: Array) -> bool:
	var it:It = arg[0]
	it.index += 1
	return it.index < it.size

func _iter_get(iter: Variant) -> Variant:
	var it:It = iter
	var idx:int = it.index
	if idx < it.buildings_start:
		if idx == 0:
			it.values = _units.values()
			return it.values.front()
		return it.values[idx]
	elif idx < it.structures_start:
		if idx == it.buildings_start:
			it.values = _buildings.values()
			return it.values.front()
		else:
			return it.values[idx - it.buildings_start]
	else:
		if idx == it.structures_start:
			it.values = _structures.values()
			return it.values.front()
		return it.values[idx - it.structures_start]
	
#endregion
