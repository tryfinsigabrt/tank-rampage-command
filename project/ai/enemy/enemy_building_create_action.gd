class_name EnemyBuildingCreateAction extends Node3D

signal on_building_complete(context: BuildBuildingUtilityContext, building:Building)

@export
var blackboard:EnemyTeamBlackboard

@onready 
var building_manufacturing: BuildingManufacturing = $BuildingManufacturing

@onready 
var ground_picker: NodePicker = $GroundPicker

@onready 
var placement_container: Node3D = $PlacementContainer

@export
var max_spawn_tries_per_frame:int = 10

@export
var spawn_timeout:float = 5.0

@export_range(0.1, 1.0, 0.1)
var radius_expansion_factor:float = 0.5

@export_range(5.0,180.0,1.0)
var angle_test_increment_deg:float = 45.0

class ActivePlacement:
	var context:BuildBuildingUtilityContext
	var spawner:NodePlacementSpawner
	var resource_bounds:BoundingCircle
	var start_time:float
	var latch:Signal
	var curr_test_radius:float
	var curr_test_angle:float
	var curr_bounds_index:int
	var failed:bool
	
	func _init(in_context:BuildBuildingUtilityContext, in_spawner:NodePlacementSpawner) -> void:
		context = in_context
		spawner = in_spawner
		
		add_user_signal("latch")
		latch = Signal(self, "latch")
		
		start_time = GameManager.game_timer.time_seconds
		resource_bounds = BoundingCircle.from_aabb(spawner.asset_aabb, true)
	
var active_placements:Array[ActivePlacement]

func _ready() -> void:
	set_process(false)
	
func can_create(context: BuildBuildingUtilityContext) -> bool:
	return building_manufacturing.can_create(context.construction.type)
	
func create(context: BuildBuildingUtilityContext) -> Building:
	var construction_resource:ConstructionResource = context.construction
	
	print_debug("%s: Create %s" % [name, EnumUtils.enum_to_string(ConstructionResource.Type, construction_resource.type)])

	var spawner:NodePlacementSpawner = building_manufacturing.create(construction_resource.type)
	if not spawner:
		on_building_complete.emit(context, null)
		return null
	
	placement_container.add_child(spawner)
	var active_placement := ActivePlacement.new(context, spawner)

	spawner.activate()
	active_placements.push_back(active_placement)

	set_process(true)
	
	var result:Building = await active_placement.latch
	on_building_complete.emit(context, result)
	return result
	
func _process(_delta: float) -> void:
	var curr_time:float = GameManager.game_timer.time_seconds
	var to_remove:Array[ActivePlacement]

	for active_placement in active_placements:
		# check for timeout
		if active_placement.failed or curr_time - active_placement.start_time >= spawn_timeout:
			push_warning("%s: Failed trying to spawn resource %s - reason: %s" % [name, active_placement.context.construction,
				"EXHAUSTED" if active_placement.failed else "TIMEOUT"])
			to_remove.push_back(active_placement)
			active_placement.latch.emit(null)
			continue
		var spawned := _try_spawn(active_placement)
		if spawned:
			print_debug("%s: Spawned %s -> %s at %s" % [name, active_placement.context.construction, spawned.name, spawned.global_position])
			to_remove.push_back(active_placement)
			active_placement.latch.emit(spawned)
		
	for i in range(to_remove.size() - 1, -1, -1):
		var placement := to_remove[i]
		active_placements.erase(placement)
		placement.spawner.queue_free()
	
	if to_remove:	
		print_debug("%s: Removed %d active placements" % [name, to_remove.size()])
			
	if not active_placements:
		print_debug("%s: No remaining active placements" % name)
		set_process(false)
		
func _try_spawn(placement:ActivePlacement) -> Building:
	# Use the bounds guidelines in  context along with the bounding sphere to try N locations on arc starting with first center
	# Expand out in a circular pattern in this radius and then move out 0.5x the asset radius and try locations around that arc
	# Offset the start angle each time up to the delta angle to increase point test coverage and wrap around once hit delta limit
	# Once exhaust testing one location, then move onto next bounds
	# It would be better too to add a group tag and place volumes on map to denote ideal spawn locations or mark poor spawn zones to exclude
	# and then can test those against the proposed locations or ideally never propose them in the first place
	# We can start with the naive version first
	var count:int = 0
	var candidate_bounds: Array[BoundingCircle] = placement.context.target_location_bounds
	var angle_inc:float = deg_to_rad(angle_test_increment_deg)
	var resource_bounds:BoundingCircle = placement.resource_bounds
	var radius_incr:float = resource_bounds.radius * radius_expansion_factor 
	var spawner:NodePlacementSpawner = placement.spawner
	
	for i in range(placement.curr_bounds_index, candidate_bounds.size()):
		placement.curr_bounds_index = i
		
		var curr_bounds:BoundingCircle = candidate_bounds[i]
		var center:Vector2 = curr_bounds.center
		var placement_bounds_radius:float = curr_bounds.radius
		
		while placement.curr_test_radius <= placement_bounds_radius:
			var curr_test_radius:float = placement.curr_test_radius
			var angle:float = placement.curr_test_angle

			while angle < TAU:
				var rotated := Vector2.from_angle(angle)
				var target_grid_pos:Vector2 = rotated * curr_test_radius + center
				# The grounded checks +- 1000 in y so can just pass zero and let it take care of the height projection
				var target_pos:Vector3 = Vector3(target_grid_pos.x, 0.0, target_grid_pos.y)
				spawner.move_to(target_pos)
				var result:Building = spawner.spawn()
				if result:
					return result
				
				# Rotation has no effect when starting at center	
				if curr_test_radius > 0:
					angle += angle_inc
				else:
					angle = TAU
				placement.curr_test_angle = angle
				count += 1
				# Exhausted time slice
				if count == max_spawn_tries_per_frame:
					return null
			placement.curr_test_angle = 0.0
			placement.curr_test_radius += radius_incr
			
		placement.curr_test_radius = 0.0
		
	# Failed - exhausted all positions
	placement.failed = true
	return null
