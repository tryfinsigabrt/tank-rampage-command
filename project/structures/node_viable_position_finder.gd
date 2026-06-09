class_name NodeViablePositionFinder extends Node

@export
var spawn_locations:Array[Node3D]

@export
var placement_bounds:Vector2

@onready var node_picker: NodePicker = $NodePicker
@onready var spawn_location_finder: SpawnLocationFinder = $SpawnLocationFinder

func place_asset(asset:Node3D) -> bool:
	spawn_location_finder.bounds = placement_bounds

	# Second time around force the spawn	
	for i in 2:
		for spawn_region in spawn_locations:
			var location:Vector3 = spawn_region.global_position
			var dir:Vector2 = MathUtils.grid_vector(-spawn_region.global_basis.z)
			
			spawn_location_finder.bounds_dir = dir
	
			var success := _attempt_placement(location, asset, i > 0)
			if success:
				return true
	return false	

func attempt_placement_at(at:Vector3, looking_at:Vector2, asset:Node3D, force:bool = false) -> bool:
	spawn_location_finder.bounds = placement_bounds
	spawn_location_finder.bounds_dir = looking_at
	
	return _attempt_placement(at, asset, force)
	

func _attempt_placement(at:Vector3, asset:Node3D, force:bool = false) -> bool:
	var open_position:Vector3 = spawn_location_finder.find_viable_spawn_grid_location(at, asset)
	if open_position == Vector3.INF:
		if force:
			open_position = at
		else:
			return false
			
	var placement_position:Vector3 = node_picker.project_to_ground(open_position)
	if placement_position == Vector3.INF:
		if force:
			placement_position = open_position
		else:
			return false
			
	asset.global_position = placement_position

	print_debug("%s: Placed asset=%s at %s -> %s" \
		% [name, asset.name, at, asset.global_position])
		
	return true
