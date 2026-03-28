class_name ManufacturingComponent extends Node

@export
var default_spawn_location:Node3D

@export
var supported_types:ManufacturingTypes

@export_range(0, 1e9, 1, "or_greater")
var max_queue:int = 5

@onready var unit_spawner: UnitSpawner = %UnitSpawner
@onready var build_timer: Timer = %BuildTimer

var _indexed_types:Dictionary[ConstructionResource.Type, ConstructionResource]

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
	
	if not default_spawn_location:
		assert(false, "%s: default_spawn_location node not set!" % name)
		default_spawn_location = Groups.get_parent_with_type(self, Node3D)
	
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
	
	return unit_spawner.spawn(resource.team_asset, default_spawn_location.global_position)

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
		_schedule_timer_for(_build_queue.front())
