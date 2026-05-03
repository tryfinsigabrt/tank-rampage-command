class_name UnitSpawner extends Node

@export
var node_picker:NodePicker

@export
var spawn_location_finder:SpawnLocationFinder

var _match_team:MatchTeam

var _container:Node

func _ready() -> void:
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	_container = _match_team
	if not _match_team:
		push_error("%s: UnitSpawner has no MatchTeam parent!" % name)
		_container = self
	assert(node_picker, "%s: Node Picker not set!" % name)
	assert(spawn_location_finder, "%s: Spawn Location Finder not set!" % name)

func configure_spawn(bounds:Vector2, bounds_dir:Vector2) -> void:
	spawn_location_finder.bounds = bounds
	spawn_location_finder.bounds_dir = bounds_dir
		
func spawn(resource:ConstructionResource, at:Vector3, unit_name:String="", force:bool = false) -> Unit:
	var scene:PackedScene = resource.team_asset
	var unit:Unit = scene.instantiate() as Unit
	if not unit:
		push_error("%s: Could not spawn scene=%s as Unit" % [name, scene])
		return null
	
	if _match_team:
		unit.team = _match_team.team
		if unit_name:
			unit.name = unit_name
	
	_configure_unit(unit, resource)
	_container.add_child(unit)
	
	var open_position:Vector3 = spawn_location_finder.find_viable_spawn_grid_location(at, unit)
	if open_position == Vector3.INF:
		if force:
			open_position = at
		else:
			return null
			
	var spawn_position:Vector3 = node_picker.project_to_ground(open_position)
	if spawn_position == Vector3.INF:
		if force:
			spawn_position = open_position
		else:
			return null
			
	unit.global_position = spawn_position

	print_debug("%s: Spawned unit=%s for team=%d at %s -> %s" \
		% [name, unit.name, unit.team, at, unit.global_position])
		
	return unit

func _configure_unit(unit:Unit, resource:ConstructionResource) -> void:
	if resource.attributes:
		unit.attributes = resource.attributes
	if resource.visual_overrides:
		unit.team_resource = resource.visual_overrides
