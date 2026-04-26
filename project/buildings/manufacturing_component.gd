class_name ManufacturingComponent extends Node

signal build_queued(resource:ConstructionResource)
signal build_started(resource:ConstructionResource)
signal build_completed(resouce:ConstructionResource, node:Node3D)

## List of spawn locations. If there is a collision at the location, then it will expand out 
## by the spawn_bounds size and if not viable then loops through remaining spawn locations before
## just falling back to the original location and trying to spawn despite a detected collision.

@export
var asset_spawner: AssetSpawner

@export
var default_spawn_locations:Array[Node3D]

@export
var spawn_bounds:Vector2 = Vector2(100.0, 100.0)

@export
var supported_types:ManufacturingTypes

@export_range(0, 1e9, 1, "or_greater")
var max_queue:int = 5

@onready var build_timer: Timer = %BuildTimer

var _indexed_types:Dictionary[ConstructionResource.Type, ConstructionResource]
var _spawn_counts:Dictionary[ConstructionResource.Type,int]
var _match_team:MatchTeam

## Toggle activation - only affects new builds - used for a building that is "under construction"
var active:bool = true

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

var available_build_slots:int:
	get:
		return max_queue - queue_depth
	
var has_free_slot:bool:
	get:
		return available_build_slots > 0
		
static func get_component(node: Node, required:bool = true) -> ManufacturingComponent:
	return Components.get_component(Components.Manufacturing, node, required) as ManufacturingComponent
		
func _enter_tree() -> void:
	Components.add_component(Components.Manufacturing, self)

func _exit_tree() -> void:
	_refund_build_queue()
	Components.remove_component(Components.Manufacturing, self)

func _refund_build_queue() -> void:
	# Refund any queued up units that haven't spawned
	if _match_team:
		for element in _build_queue:
			element.resource.refund_fully(_match_team.resources)
			
func _ready() -> void:
	assert(asset_spawner, "asset_spawner not set!")
	if supported_types:
		for construction in supported_types.types:
			var type := construction.type
			if type:
				_indexed_types[type] = construction
	
	if not default_spawn_locations:
		assert(false, "%s: default_spawn_locations not set!" % name)
		default_spawn_locations = [Groups.get_parent_with_type(self, Node3D)]
		
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	
	if not _match_team:
		push_error("%s: ManufacturingComponent has no MatchTeam parent!" % name)
	
func get_build_metadata(type: ConstructionResource.Type) -> ConstructionResource:
	return _indexed_types.get(type)
	
func can_build(type: ConstructionResource.Type) -> bool:
	if not active:
		return false
		
	var resource: ConstructionResource = _indexed_types.get(type)
	if not resource:
		return false
	if not has_free_slot:
		return false
	if not _match_team:
		return true
	
	return resource.can_build(_match_team.resources)
	
func build(type: ConstructionResource.Type) -> Node3D:
	if not can_build(type):
		return null
		
	var resource:ConstructionResource = _indexed_types.get(type)
	if not resource:
		push_warning("%s: Type=%s cannot be built by this component!" % [name, type])
		return null
	
	# Spend resources immediately
	if _match_team:
		resource.spend(_match_team.resources)
		
	var unit := await _do_spawn(resource)
	if _match_team:
		if unit:
			# Now count against army size
			resource.spend_personnel_only(_match_team.resources)
			resource.assign_to(unit)
		else:
			resource.refund_fully(_match_team.resources)
			
	return unit

func _do_spawn(resource:ConstructionResource) -> Node3D:
	# If queue depth too high then fail spawning
	if _build_queue.size() >= max_queue:
		print_debug("%s: Build queue already at capacity of %d - returning null" % [name, max_queue])
		return null
		
	var queue_elm := BuildQueueElement.new(resource)
	_build_queue.push_back(queue_elm)
	build_queued.emit(resource)
	
	if build_timer.is_stopped():
		_schedule_timer_for(resource)
	
	await queue_elm.latch
	
	var asset_name:String = _create_asset_name(resource.type)
	
	# TODO: Canceling?
	var asset:Node3D = asset_spawner.spawn(resource, asset_name)
	build_completed.emit(resource, asset)
	
	return asset

func _create_asset_name(type: ConstructionResource.Type) -> String:
	var cnt:int = _spawn_counts.get(type, 0)
	_spawn_counts[type] = cnt + 1
	
	# Format count with leading zero
	return "%s%02d" % [EnumUtils.enum_to_string(ConstructionResource.Type, type), cnt + 1]
	
func _schedule_timer_for(resource:ConstructionResource) -> void:
	build_timer.wait_time = resource.time
	build_timer.start()
	
	build_started.emit(resource)

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
