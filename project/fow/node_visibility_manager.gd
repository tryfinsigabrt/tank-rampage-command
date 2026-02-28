class_name NodeVisibilityManager extends Node

@export
var fog_of_war:FogOfWar

@export
var visibility_tick_rate:float = 0.23

## Individual red or green color channel value that is used to check if we flag that node as visible
@export
var visible_channel_threshold:float = 0.3

var _registered_visibility_nodes: Dictionary[int, Node3D] = {}
var _cached_nodes: Array[Node3D]
var _nodes_dirty:bool
var _accum_delta:float

func _enter_tree() -> void:
	SignalBus.on_unit_added.connect(_on_unit_added)
	SignalBus.on_unit_killed.connect(_on_unit_killed.unbind(1))

func _ready() -> void:
	if not fog_of_war:
		push_error("%s: Fog of War node not set" % name)
		enable = false
		return
			
var enable:bool = true:
	set(value):
		if value == enable:
			return
			
		enable = value
		process_mode = Node.PROCESS_MODE_PAUSABLE if enable else Node.PROCESS_MODE_DISABLED
		
		if not value:
			if SignalBus.on_unit_added.is_connected(_on_unit_added):
				SignalBus.on_unit_added.disconnect(_on_unit_added)
			if SignalBus.on_unit_killed.is_connected(_on_unit_killed):
				SignalBus.on_unit_killed.disconnect(_on_unit_killed)
		
# Use process for smoother tick rate
func _process(delta: float) -> void:
	_accum_delta += delta
	
	if _accum_delta < visibility_tick_rate:
		return
	
	if _nodes_dirty:
		_cached_nodes = _registered_visibility_nodes.values() as Array[Node3D]
		_nodes_dirty = false
		# Skip this frame
		return
		
	_update()
	_accum_delta = 0.0
	
func _update() -> void:
	for node in _cached_nodes:
		if is_instance_valid(node) and node.is_in_group(Groups.Unit):
			var world_pos:Vector3 = node.global_position
			var fow_color:Color = fog_of_war.get_fow_value(world_pos)
			var visible:bool = fow_color.r >= visible_channel_threshold
			node.render = visible
			node.set_visible_to(fog_of_war.player_team, visible)
		# TODO: Buildings require a more complex approach using its AABB and checking if any point is above the threshold
	
	
func _on_unit_added(unit:Unit) -> void:
	if unit.is_on_team(fog_of_war.player_team):
		return
		
	_registered_visibility_nodes[unit.get_instance_id()] = unit
	_nodes_dirty = true

func _on_unit_killed(unit:Unit) -> void:
	if unit.is_on_team(fog_of_war.player_team):
		return
		
	_registered_visibility_nodes.erase(unit.get_instance_id())
	_nodes_dirty = true
