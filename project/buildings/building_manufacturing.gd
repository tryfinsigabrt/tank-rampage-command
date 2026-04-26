class_name BuildingManufacturing extends Node

@export
var supported_types:ManufacturingTypes

@export
var node_placement_spawner_scene:PackedScene

var _indexed_types:Dictionary[ConstructionResource.Type, ConstructionResource]
var _match_team:MatchTeam
var _spawn_counts:Dictionary[ConstructionResource.Type,int]

func _ready() -> void:
	assert(node_placement_spawner_scene, "node_placement_spawner_scene not set!")
	if supported_types:
		for construction in supported_types.types:
			var type := construction.type
			if type:
				_indexed_types[type] = construction
		
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	
	if not _match_team:
		push_error("%s: ManufacturingComponent has no MatchTeam parent!" % name)

func get_build_metadata(type: ConstructionResource.Type) -> ConstructionResource:
	return _indexed_types.get(type)
	
func can_create(type: ConstructionResource.Type) -> bool:
	var resource: ConstructionResource = get_build_metadata(type)
	if not resource:
		return false
	if not _match_team:
		return true
	
	return resource.can_build(_match_team.resources)
			
func create(type: ConstructionResource.Type) -> NodePlacementSpawner:
	if not can_create(type):
		return null
	
	var resource:ConstructionResource = _indexed_types[type]
	
	var placement_spawner:NodePlacementSpawner = node_placement_spawner_scene.instantiate()
	placement_spawner.match_team = _match_team
	placement_spawner.resource = resource.placement_spawner_resource
	
	var resources:TeamResources
	if _match_team:
		resources = _match_team.resources
		resource.spend(resources)
	else:
		resources = null
	
	var spawn_count:PackedInt32Array = [0]
	
	placement_spawner.on_spawn.connect(func(asset:Node3D) -> void:
		asset.name = _create_asset_name(type)
		print_debug("%s: Assigning asset %s resource=%s" % \
			[name, asset.name, EnumUtils.enum_to_string(ConstructionResource.Type, type)])
		if resources:
			resource.spend_personnel_only(resources)
		resource.assign_to(asset)
		
		var construction_scene:PackedScene = resource.construction_scene
		if construction_scene:
			var construction_node := construction_scene.instantiate()
			# TODO: Refactor ConstructionBuilding to a component
			var construction_building: ConstructionBuilding = Groups.get_child_with_type(construction_node, ConstructionBuilding)
			if construction_building:
				construction_building.resource = resource
			
			asset.add_child(construction_node)
			
		spawn_count[0] += 1
	)
	
	if resources:
		placement_spawner.tree_exited.connect(func() -> void:
			if spawn_count[0] == 0:
				print_debug("%s: Placement Spawner=%s destroyed before asset spawned for resource=%s" % \
				[name, placement_spawner.name, EnumUtils.enum_to_string(ConstructionResource.Type, type)])
				resource.refund_fully(resources)
		)
		
	return placement_spawner

func _create_asset_name(type: ConstructionResource.Type) -> String:
	var cnt:int = _spawn_counts.get(type, 0)
	_spawn_counts[type] = cnt + 1
	
	# Format count with leading zero
	return "%s%02d" % [EnumUtils.enum_to_string(ConstructionResource.Type, type), cnt + 1]
