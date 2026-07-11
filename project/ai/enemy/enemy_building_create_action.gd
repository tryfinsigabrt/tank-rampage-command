class_name EnemyBuildingCreateAction extends Node3D

signal on_building_complete(context: AbstractBuildPlacementUtilityContext, building:Building)
signal on_structure_complete(context: AbstractBuildPlacementUtilityContext, structure:DefensiveStructure)

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

@export
var spawn_point_randomization_count:int = 100

var _inventory_component:InventoryComponent

class ActivePlacement:
	var context:AbstractBuildPlacementUtilityContext
	var spawner:NodePlacementSpawner
	var resource_bounds:BoundingCircle
	var start_time:float
	var latch:Signal
	var curr_test_radius:float
	var curr_test_angle:float
	var curr_bounds_index:int
	var failed:bool
	var points:Array[Vector2]
	var points_index:int
	
	func _init(in_context:AbstractBuildPlacementUtilityContext, in_spawner:NodePlacementSpawner) -> void:
		context = in_context
		spawner = in_spawner
		
		add_user_signal("latch")
		latch = Signal(self, "latch")
		
		start_time = GameManager.game_timer.time_seconds
		resource_bounds = BoundingCircle.from_aabb(spawner.asset_aabb, true)
	
var active_placements:Array[ActivePlacement]

func _ready() -> void:	
	set_process(false)
	
	var match_team:MatchTeam = Groups.get_parent_with_type(self, MatchTeam)
	assert(match_team)
	await NodeUtils.ensure_ready(match_team)
	
	_inventory_component = match_team.inventory_component

func can_create(context: AbstractBuildPlacementUtilityContext) -> bool:
	var resource := context.construction
	var classification := resource.classification
	
	match classification:
		ConstructionResource.Classification.Building:
			return building_manufacturing.can_create(resource.type)
		ConstructionResource.Classification.Structure:
			return _inventory_component.has(resource.type)
		_:
			push_warning("%s: Resource %s has unsupported classification of %s" \
			% [name, resource, EnumUtils.enum_to_string(ConstructionResource.Classification, classification)])
			return false
	
func create(context: AbstractBuildPlacementUtilityContext) -> Node3D:
	var construction_resource:ConstructionResource = context.construction
	var classification := construction_resource.classification

	print_debug("%s: Create %s" % [name, EnumUtils.enum_to_string(ConstructionResource.Type, construction_resource.type)])

	var spawner:NodePlacementSpawner
	var sig:Signal
	
	match classification:
		ConstructionResource.Classification.Building:
			spawner = building_manufacturing.create(construction_resource.type)
			sig = on_building_complete
		ConstructionResource.Classification.Structure:
			spawner = _inventory_component.create(construction_resource.type)
			sig = on_structure_complete
		_:
			push_warning("%s: Resource %s has unsupported classification of %s" \
			% [name, construction_resource, EnumUtils.enum_to_string(ConstructionResource.Classification, classification)])
			spawner = null
			
	var result := await _create(context, spawner)
	if not sig.is_null():
		sig.emit(context, result)
	
	return result

func _create(context: AbstractBuildPlacementUtilityContext, spawner: NodePlacementSpawner)	 -> Node3D:
	if not spawner:
		return null
	
	placement_container.add_child(spawner)
	var active_placement := ActivePlacement.new(context, spawner)

	spawner.activate()
	active_placements.push_back(active_placement)

	set_process(true)
	
	var result:Node3D = await active_placement.latch
	
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

func _next_point(placement:ActivePlacement) -> Vector2:
	var points := placement.points
	var idx := placement.points_index
	if idx < points.size():
		var point := points[idx]
		placement.points_index = idx + 1
		return point
	if _fill_next_points(placement):
		# Randomize next point
		points.shuffle()
		var point: Vector2 = points.front()
		placement.points_index = 1
		return point
		
	# Sentinel value indicating we exhausted all possible points
	return Vector2.INF
	
func _fill_next_points(placement:ActivePlacement) -> bool:
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
	
	var points := placement.points
	points.clear()
	placement.points_index = 0
	
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
				points.push_back(target_grid_pos)
				
				# Rotation has no effect when starting at center	
				if curr_test_radius > 0:
					angle += angle_inc
				else:
					angle = TAU
				placement.curr_test_angle = angle
				count += 1
				# Exhausted time slice
				if count == spawn_point_randomization_count:
					return true
			placement.curr_test_angle = 0.0
			placement.curr_test_radius += radius_incr
			
		placement.curr_test_radius = 0.0
		
	return not points.is_empty()
		
func _try_spawn(placement:ActivePlacement) -> Node3D:
	# Use the bounds guidelines in context along with the bounding sphere to try N locations on arc starting with first center
	# Expand out in a circular pattern in this radius and then move out 0.5x the asset radius and try locations around that arc
	# Offset the start angle each time up to the delta angle to increase point test coverage and wrap around once hit delta limit
	# Once exhaust testing one location, then move onto next bounds
	# It would be better too to add a group tag and place volumes on map to denote ideal spawn locations or mark poor spawn zones to exclude
	# and then can test those against the proposed locations or ideally never propose them in the first place
	# We can start with the naive version first
	var spawner:NodePlacementSpawner = placement.spawner

	for count in max_spawn_tries_per_frame:
		var target_grid_pos:Vector2 = _next_point(placement)
		if target_grid_pos == Vector2.INF:
			# Failed - exhausted all positions
			placement.failed = true
			return null
		# The grounded checks +- 1000 in y so can just pass zero and let it take care of the height projection
		var target_pos:Vector3 = Vector3(target_grid_pos.x, 0.0, target_grid_pos.y)
		spawner.move_to(target_pos)
		var result:Node3D = spawner.spawn()
		if result:
			return result
			
	# Exhausted time slice	
	return null
