class_name NodeViablePositionFinder extends Node

@export
var spawn_locations:Array[Node3D]

@export
var placement_bounds:Vector2

@export
var use_model_front_rotation:bool = true

@onready var node_picker: NodePicker = $NodePicker
@onready var spawn_location_finder: SpawnLocationFinder = $SpawnLocationFinder

func place_asset(asset:Node3D) -> bool:
	spawn_location_finder.bounds = placement_bounds

	# Second time around force the spawn	
	for i in 2:
		for spawn_region in spawn_locations:
			var location:Vector3 = spawn_region.global_position
			var forward_dir:Vector3 = -spawn_region.global_basis.z
				
			var success := _attempt_placement(location, forward_dir, asset, i > 0)
			if success:
				return true
	return false	

func attempt_placement_at(at:Vector3, forward_dir:Vector3, asset:Node3D, force:bool = false) -> bool:
	spawn_location_finder.bounds = placement_bounds
	spawn_location_finder.bounds_dir = MathUtils.grid_vector(forward_dir)
	
	return _attempt_placement(at, forward_dir, asset, force)
	

func _attempt_placement(at:Vector3, forward_dir:Vector3, asset:Node3D, force:bool = false) -> bool:
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
	
	# Set the rotation to face the forward_dir
	# Basis.looking_at has to be a position and not a direction
	var looking_at:Vector3 = placement_position + forward_dir * 100.0
	asset.global_rotation = Basis.looking_at(looking_at, asset.global_basis.y, use_model_front_rotation).get_euler()

	print_debug("%s: Placed asset=%s at %s -> %s" \
		% [name, asset.name, at, asset.global_position])
		
	return true
