class_name MiniMap extends SubViewportContainer

@onready var _mini_map_viewport: SubViewport = $MiniMapViewport

var _camera:RTSCamera
var _world_aabb:AABB

func _ready() -> void:
	var player:Player = get_tree().get_first_node_in_group(Groups.Player) as Player
	if not player:
		push_warning("%s: No player node in scene - camera positioning not available" % name)
		set_process_input(false)
		return
	_camera = player.camera
	if not _camera:
		push_warning("%s: MiniMap must be positioned at the bottom of the scene tree!" % name)
		set_process_input(false)
		return
		
	var world_boundaries:WorldBoundaries = get_tree().get_first_node_in_group(Groups.WorldBoundaries)
	if world_boundaries:
		_world_aabb = world_boundaries.bounds
	else:
		push_warning("%s: No world boundaries in scene - falling back to static 1000x1000x1000 world size" % name)
		_world_aabb = AABB(Vector3.ZERO, Vector3(500.0,500.0,500.0))
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mini_map_navigate"):
		_move_camera_to_cursor()

func _move_camera_to_cursor() -> void:	
	var minimap_pos:Vector2 = _mini_map_viewport.get_mouse_position()
	var world_pos:Vector3 = _get_world_position_from_minimap_pos(minimap_pos)
	
	print_debug("%s: Minimap position: %s -> %s" % [name, minimap_pos, world_pos])
	
	_camera.global_position = world_pos
	
func _get_world_position_from_minimap_pos(pos:Vector2) -> Vector3:
	# Retain same y coordinate on camera
	var y_coord:float = _camera.global_position.y
	
	var viewport_size:Vector2 = _mini_map_viewport.size
	var uv:Vector2 = (pos / viewport_size).clampf(0.0, 1.0)
	
	var world_size:Vector3 = _world_aabb.size
	var world_offset:Vector3 = _world_aabb.position
	
	return Vector3(
		world_offset.x + world_size.x * uv.x,
		y_coord,
		world_offset.z + world_size.z * uv.y
	)
