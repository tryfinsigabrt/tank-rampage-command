extends Node3D

const attack_action_scene = preload("res://player/attack_action.tscn")

@export
var ray_cast_distance:float = 10000

@export
var camera:Camera3D

@export
var team:int

var _selected_unit:Unit

enum Mode
{
	NONE,
	MOVE,
	ATTACK
}

var _mode:Mode = Mode.NONE

@onready var actions_container: Node3D = $ActionsContainer

func _ready() -> void:
	if not camera:
		_pick_camera.call_deferred()

func _pick_camera() -> void:
	camera = get_viewport().get_camera_3d()
	print_debug("%s: Defaulting to use current viewport camera: %s" % [name, camera])

func _check_for_mode(event: InputEvent) -> void:
	if event.is_action_pressed("unit_mode_attack"):
		_mode = Mode.ATTACK
	elif event.is_action_pressed("unit_mode_move"):
		_mode = Mode.MOVE
	
func _unhandled_input(event: InputEvent) -> void:
	# Only process if visible
	if not camera or not is_visible_in_tree():
		return
		
	_check_for_mode(event)

	# TODO: THis is the "commit" left click mode that also depends on the 
	# action mode like "move" or "attack" (M or A)
	if event.is_action_pressed("unit_select"):
		_handle_select(event)	
	# This is the context-aware "right click" mode that doesn't take _mode into account	
	# Attacks unit if selects an enemy unit, follows an ally unit
	elif event.is_action_pressed("unit_move_to"):
		_handle_context_action(event)
	
func _handle_context_action(event: InputEvent) -> void:
	if not _selected_unit:
		return
	_handle_move_to(event)
	# TODO: Will need to attack along the path		
	
func _handle_move_to(event: InputEvent) -> Dictionary:
	var result := _pick_node(event, Collisions.CompositeMasks.ground)
	if not result:
		return {}
	
	_clear_all_actions()
	
	var return_value:Dictionary = {}
	var move_to_position:Vector3 = result.get("position")
	
	return_value["position"] = move_to_position
	
	_issue_move_to(move_to_position)
	
	return return_value
	
func _handle_select(event: InputEvent) -> void:
	match _mode:
		Mode.NONE: _handle_unit_select(event)
		Mode.ATTACK: _handle_attack(event)
		Mode.MOVE: _handle_move_to(event)
		_ : return

func _handle_attack(event: InputEvent) -> void:
	# Move to location
	var result:Dictionary = _handle_move_to(event)
	# TODO: Only attack threats while moving
	# Right now just attacking the location itself repeatedly
	if result and _selected_unit:
		_clear_all_actions()
		var attack_scene:AttackAction = attack_action_scene.instantiate()
		attack_scene.controlled_unit = _selected_unit
		attack_scene.targeted_location = result.get("position")
		
		actions_container.add_child(attack_scene)

func _clear_all_actions() -> void:
	for node in actions_container.get_children():
		node.queue_free()
	
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
			DebugDraw3D.draw_sphere(
				new_unit.global_position, 5.0
				,Color.GREEN if _selected_unit.team == team else Color.ORANGE
				, 3.0)
	else:
		_selected_unit = null
		
func _issue_move_to(target_position: Vector3) -> void:
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(target_position, 5.0, Color.YELLOW, 3.0)
		
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
