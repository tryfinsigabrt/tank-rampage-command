class_name EnemyBuildingCreateAction extends Node3D

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

class ActivePlacement:
	var context:BuildBuildingUtilityContext
	var spawner:NodePlacementSpawner
	var resource_bounds:BoundingSphere
	var start_time:float
	var latch:Signal
	
	func _init(in_context:BuildBuildingUtilityContext, in_spawner:NodePlacementSpawner) -> void:
		context = in_context
		spawner = in_spawner
		
		add_user_signal("latch")
		latch = Signal(self, "latch")
		
		start_time = GameManager.game_timer.time_seconds
		resource_bounds = Bounds.create_circumscribed_sphere(spawner.asset_aabb)
	
var active_placements:Array[ActivePlacement]

func _ready() -> void:
	set_process(false)
	
func create(context: BuildBuildingUtilityContext) -> Building:
	var construction_resource:ConstructionResource = context.construction
	
	print_debug("%s: Create %s" % [name, EnumUtils.enum_to_string(ConstructionResource.Type, construction_resource.type)])

	var spawner:NodePlacementSpawner = building_manufacturing.create(construction_resource.type)
	if not spawner:
		return null
	
	placement_container.add_child(spawner)
	var active_placement := ActivePlacement.new(context, spawner)

	spawner.activate()
	active_placements.push_back(active_placement)

	set_process(true)
	
	return await active_placement.latch
	
func _process(_delta: float) -> void:
	var curr_time:float = GameManager.game_timer.time_seconds
	var to_remove:Array[ActivePlacement]

	for active_placement in active_placements:
		# check for timeout
		if curr_time - active_placement.start_time >= spawn_timeout:
			push_warning("%s: Timed out trying to spawn resource %s" % [name, active_placement.construction])
			to_remove.push_back(active_placement)
			active_placement.latch.emit(null)
			continue
		var spawned := _try_spawn(active_placement)
		if spawned:
			print_debug("%s: Spawned %s -> %s" % [name, active_placement.construction, spawned.name])
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
		
func _try_spawn(_placement:ActivePlacement) -> Building:
	# TODO: Use the bounds guidelines in  context along with the bounding sphere to try N locations on arc starting with first center
	# Expand out in a circular pattern in this radius and then move out 0.5x the asset radius and try locations around that arc
	# Offset the start angle each time up to the delta angle to increase point test coverage and wrap around once hit delta limit
	# Once exhaust testing one location, then move onto next bounds
	# It would be better too to add a group tag and place volumes on map to denote ideal spawn locations or mark poor spawn zones to exclude
	# and then can test those against the proposed locations or ideally never propose them in the first place
	# We can start with the naive version first
	return null
