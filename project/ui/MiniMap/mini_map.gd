class_name MiniMap extends SubViewportContainer

@onready var _mini_map_viewport: SubViewport = $MiniMapViewport
@onready var location_picker: NodePicker = %LocationPicker

var _camera:RTSCamera

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
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mini_map_navigate"):
		# Capture local mouse position
		var local_pos := get_local_mouse_position()
		if not Rect2(Vector2.ZERO, size).has_point(local_pos):
			return

		_move_camera_to_cursor(local_pos)

func _move_camera_to_cursor(local_pos:Vector2) -> void:
	var scale_factor := 	Vector2(_mini_map_viewport.size) / size
	var viewport_pos := local_pos * scale_factor
	
	var result:Dictionary = location_picker.pick_position(viewport_pos, Collisions.CompositeMasks.ground)
	if not result:
		return
	
	var world_pos:Vector3 = result["position"]
	# Maintain existing y offset
	world_pos.y = _camera.global_position.y
	
	print_debug("%s: Minimap position: %s -> %s" % [name, viewport_pos, world_pos])
	
	_camera.global_position = world_pos
