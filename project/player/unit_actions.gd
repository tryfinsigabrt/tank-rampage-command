extends Node3D

@export
var ray_cast_distance:float = 10000

@export
var camera:Camera3D

@export
var team:int

var _selected_unit:Unit

func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
		print_debug("%s: Defaulting to use current viewport camera: %s" % [name, camera])

func _unhandled_input(event: InputEvent) -> void:
	# Only process if visible
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("unit_select"):
		_handle_unit_select(event)
	elif event.is_action_pressed("unit_move_to"):
		_handle_move_to(event)
	
func _handle_move_to(event: InputEvent) -> void:
	if not _selected_unit:
		return
	var result := _pick_node(event, Collisions.CompositeMasks.ground)
	if not result:
		return
	_issue_move_to(result.get("position"))
	
func _handle_unit_select(event: InputEvent) -> void:
	var new_unit:Unit = _pick_unit(event)

	# Clicking on your unit twice deselects
	# TODO: Double check this behavior if it is a standard or makes sense in RTS
	if _selected_unit:
		print_debug("%s: De-select unit=%s" % [name, _selected_unit])
		SignalBus.on_unit_deselected.emit(_selected_unit)
	
	if new_unit and new_unit != _selected_unit:
		_selected_unit = new_unit
		SignalBus.on_unit_selected.emit(new_unit)
		
		print_debug("%s: Selected unit=%s on team=%d; out_team=%d" % [name, new_unit.name, new_unit.team, team])
		if OS.is_debug_build():
			DebugDraw3D.draw_sphere(new_unit.global_position, 2.0, Color.GREEN if _selected_unit.team == team else Color.ORANGE)
	else:
		_selected_unit = null
	
func _issue_move_to(target_position: Vector3) -> void:
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(target_position, 2.0, Color.YELLOW)
		
	SignalBus.on_unit_move_issued.emit(_selected_unit, target_position)
	
func _pick_unit(event: InputEvent) -> Unit:
	var result := _pick_node(event, Collisions.Layers.unit)
	if not result:
		return
	var clicked_object = result.collider
	return Groups.get_parent_in_group(clicked_object, Groups.Unit)
	
func _pick_node(event: InputEvent, collision_mask:int) -> Dictionary:
	var from := camera.project_ray_origin(event.position)
	var to := from + camera.project_ray_normal(event.position) * ray_cast_distance  # Long ray

	var space_state := get_world_3d().direct_space_state
	
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.collision_mask = collision_mask
	ray_params.from = from
	ray_params.to = to
	
	return space_state.intersect_ray(ray_params)
