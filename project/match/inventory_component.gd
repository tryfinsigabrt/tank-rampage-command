class_name InventoryComponent extends Node

signal inventory_changed

@export
var node_placement_spawner_scene:PackedScene

var _match_team:MatchTeam
var _inventory_containers_by_type:Dictionary[ConstructionResource.Type,Node]

func _ready() -> void:
	assert(node_placement_spawner_scene, "%s: node_placement_spawner_scene not set!" % name)

	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	if not _match_team:
		assert("%s: Could not find MatchTeam parent" % name)
		queue_free()
		return

func add_structure(proxy:StructureProxy) -> void:
	var type:ConstructionResource.Type = proxy.resource.type
	
	var container:Node = _inventory_containers_by_type.get(type)
	if not container:
		print_debug("%s: Create new container for type=%s" % [name, EnumUtils.enum_to_string(ConstructionResource.Type, type)])
		container = Node.new()
		container.name = EnumUtils.enum_to_string(ConstructionResource.Type, type)
		add_child(container)
		_inventory_containers_by_type[type] = container
	
	proxy.count = proxy.resource.count	
	container.add_child(proxy)
	inventory_changed.emit()

func has(type: ConstructionResource.Type) -> int:
	return get_count(type) > 0

func get_available_types() -> Array[ConstructionResource.Type]:
	var available_types:Array[ConstructionResource.Type]
	for type in _inventory_containers_by_type:
		var container:Node = _inventory_containers_by_type[type]
		if container.get_child_count() > 0:
			available_types.push_back(type)
	
	return available_types
	 	
func get_count(type: ConstructionResource.Type) -> int:
	var container:Node = _inventory_containers_by_type.get(type)
	if not container:
		return 0
	var count:int = 0
	for proxy:StructureProxy in container.get_children():
		count += proxy.count
	return count

func get_resource(type: ConstructionResource.Type) -> ConstructionResource:
	var container:Node = _inventory_containers_by_type.get(type)
	if not container or container.get_child_count() == 0:
		return null
	var proxy := container.get_child(0) as StructureProxy
	return proxy.resource if proxy else null

func create(type:ConstructionResource.Type) -> NodePlacementSpawner:
	if not has(type):
		return null
	
	var type_container:Node = _inventory_containers_by_type[type]
	var structure_proxy:StructureProxy = type_container.get_children().back()
	# Initially orphan the structure proxy and then will add it back if spawning is canceled
	structure_proxy.count -= 1
	
	var removed:bool = false
	if structure_proxy.count == 0:
		removed = true
		type_container.remove_child(structure_proxy)
	inventory_changed.emit()
	
	var resource:ConstructionResource = structure_proxy.resource
	
	var placement_spawner:NodePlacementSpawner = node_placement_spawner_scene.instantiate()
	placement_spawner.match_team = _match_team
	placement_spawner.resource = resource.placement_spawner_resource
	
	var spawn_count:PackedInt32Array = [0]
	
	placement_spawner.on_spawn.connect(func(asset:Node3D) -> void:
		asset.name = structure_proxy.name
		# No construction scene - the player has already paid the wait cost to have it manufactured, so place immediately			
		spawn_count[0] += 1
	)
	
	placement_spawner.tree_exited.connect(func() -> void:
		if spawn_count[0] > 0:
			# Free the proxy if it was removed since the resource was created
			if removed:
				structure_proxy.queue_free()
		else:
			print_debug("%s: Placement Spawner=%s destroyed before asset spawned for resource=%s" % \
				[name, placement_spawner.name, EnumUtils.enum_to_string(ConstructionResource.Type, type)])
			# Add it back to the inventory if it was removed after first increasing the count back
			structure_proxy.count += 1
			if removed:
				type_container.add_child(structure_proxy)
			inventory_changed.emit()
	)
	return placement_spawner
