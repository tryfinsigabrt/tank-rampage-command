class_name ManufacturingComponent extends Node

## List of spawn locations. If there is a collision at the location, then it will expand out 
## by the spawn_bounds size and if not viable then loops through remaining spawn locations before
## just falling back to the original location and trying to spawn despite a detected collision.

@export
var default_spawn_locations:Array[Node3D]

@export
var spawn_bounds:Vector2 = Vector2(100.0, 100.0)

@export
var supported_types:ManufacturingTypes

@export_range(0, 1e9, 1, "or_greater")
var max_queue:int = 5

@onready var unit_spawner: UnitSpawner = %UnitSpawner
@onready var build_timer: Timer = %BuildTimer

var _indexed_types:Dictionary[ConstructionResource.Type, ConstructionResource]
var _spawn_counts:Dictionary[ConstructionResource.Type,int]

class BuildQueueElement:
	var latch:Signal
	var resource:ConstructionResource
	
	func _init(in_resource:ConstructionResource) -> void:
		resource = in_resource
		add_user_signal("latch")
		latch = Signal(self, "latch")
	
var _build_queue: Array[BuildQueueElement]

var queue_depth:int:
	get:
		return _build_queue.size()
		
func _enter_tree() -> void:
	Components.add_component(Components.Manufacturing, self)

func _exit_tree() -> void:
	Components.remove_component(Components.Manufacturing, self)
	
func _ready() -> void:
	if supported_types:
		for construction in supported_types.types:
			var type := construction.type
			if type:
				_indexed_types[type] = construction
	
	if not default_spawn_locations:
		assert(false, "%s: default_spawn_locations not set!" % name)
		default_spawn_locations = [Groups.get_parent_with_type(self, Node3D)]
	
	unit_spawner.spawn_location_finder.bounds = spawn_bounds
	
func can_build(type: ConstructionResource.Type) -> bool:
	# TODO: Check resource limits
	return type in _indexed_types
	
func build(type: ConstructionResource.Type) -> Node3D:
	var resource:ConstructionResource = _indexed_types.get(type)
	if not resource:
		push_warning("%s: Type=%s cannot be built by this component!" % [name, type])
		return null
	
	var unit := 	await _do_spawn(resource)
	return unit

func _do_spawn(resource:ConstructionResource) -> Node3D:
	# If queue depth too high then fail spawning
	if _build_queue.size() >= max_queue:
		print_debug("%s: Build queue already at capacity of %d - returning null" % [name, max_queue])
		return null
		
	var queue_elm := BuildQueueElement.new(resource)
	_build_queue.push_back(queue_elm)
	if build_timer.is_stopped():
		_schedule_timer_for(resource)
	
	await queue_elm.latch
	
	# Second time around force the spawn	
	var unit_name:String = _create_unit_name(resource.type)
	
	for i in 2:
		for spawn_region in default_spawn_locations:
			var spawn_location:Vector3 = spawn_region.global_position
			var spawn_dir:Vector3 = -spawn_region.global_basis.z
			var spawn_dir2:Vector2 = Vector2(spawn_dir.x, spawn_dir.z)
			unit_spawner.configure_spawn(spawn_bounds, spawn_dir2)
			var unit := unit_spawner.spawn(resource.team_asset, spawn_location, unit_name, i > 0)
			if unit:
				return unit
	return null

func _create_unit_name(type: ConstructionResource.Type) -> String:
	var cnt:int = _spawn_counts.get(type, 0)
	_spawn_counts[type] = cnt + 1
	
	# Format count with leading zero
	return "%s%02d" % [EnumUtils.enum_to_string(ConstructionResource.Type, type), cnt + 1]
	
func _schedule_timer_for(resource:ConstructionResource) -> void:
	build_timer.wait_time = resource.time
	build_timer.start()

func _on_build_timer_timeout() -> void:
	var queue_elm: BuildQueueElement = _build_queue.pop_front()
	if not queue_elm:
		push_warning("%s: Build timer fired but nothing to build!" % name)
		return
	print_debug("%s: Build time finished for %s" % [name, queue_elm.resource])
	
	queue_elm.latch.emit()
	
	# Schedule next if not empty
	if _build_queue:
		_schedule_timer_for(_build_queue.front().resource)
