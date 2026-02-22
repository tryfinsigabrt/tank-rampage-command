class_name PlayerUnitActions extends Node3D

@export
var team:int:
	set(value):
		if selection_manager:
			selection_manager.team = value
		team = value
	get:
		return team

enum Mode
{
	NONE,
	MOVE,
	ATTACK
}

var _mode:Mode = Mode.NONE

@onready var node_picker: NodePicker = $NodePicker
@onready var selection_manager: SelectionManager = $SelectionManager
@onready var order_manager: OrderManager = $OrderManager

var enabled:bool:
	get: return is_processing_unhandled_input()
	set(value):
		set_process_unhandled_input(value)
		
func _ready() -> void:
	selection_manager.team = team
	
	if is_visible_in_tree():
		enabled = true

func _check_for_mode(event: InputEvent) -> bool:
	if not selection_manager.any:
		return false
		
	if event.is_action_pressed("unit_mode_attack"):
		if _mode != Mode.ATTACK:
			_mode = Mode.ATTACK
			get_viewport().set_input_as_handled()
			return true
	elif event.is_action_pressed("unit_mode_move"):
		if _mode != Mode.MOVE:
			_mode = Mode.MOVE
			get_viewport().set_input_as_handled()
			return true
	return false
	
func _unhandled_input(event: InputEvent) -> void:
	# Only process if visible
	if not node_picker.is_valid or not is_visible_in_tree():
		return
		
	if _check_for_mode(event):
		return

	if event.is_action_pressed("unit_select", false, true):
		_handle_select(event)
	elif event.is_action_pressed("unit_multi_toggle_select", false, true):
		_handle_toggle_unit(event)
	elif event.is_action_pressed("unit_type_select", false, true):
		_handle_select_all_of_type(event)
	elif event.is_action_pressed("unit_select_all", false, true):
		_handle_select_all(event)
		
	# This is the context-aware "right click" mode that doesn't take _mode into account	
	# Attacks unit if selects an enemy unit, follows an ally unit
	elif event.is_action_pressed("unit_move_to"):
		_handle_context_action(event)
	
func _handle_toggle_unit(event: InputEvent) -> void:
	var unit := node_picker.pick_unit(event)
	if unit:
		selection_manager.toggle(unit)

func _handle_select_all_of_type(event: InputEvent) -> void:
	var unit := node_picker.pick_unit(event)
	if not unit:
		return
	selection_manager.set_selection_multiple(unit.get_all_units_same_team_and_class())

func _handle_select_all(event: InputEvent) -> void:
	var unit := node_picker.pick_unit(event)
	if not unit:
		return
	selection_manager.set_selection_multiple(unit.get_all_units_on_same_team())
		
func _handle_context_action(event: InputEvent) -> void:
	var selected_unit:Unit = node_picker.pick_unit(event)
	if selected_unit:
		if selected_unit.is_on_team(team):
			# TODO: Follow not currently implemented so just move to
			_move_to(event)
		else:
			order_manager.attack(selected_unit)
	else:
		_move_to(event)
	
func _can_issue_orders_to_unit(unit: Unit) -> bool:
	return unit and unit.team == team
	
func _move_to(event: InputEvent) -> void:
	if not selection_manager.any_same_team:
		return
		
	var result := node_picker.pick_ground(event)
	if not result:
		return
				
	var move_to_position:Vector3 = result.get("position")
	order_manager.move(move_to_position)
	
func _handle_select(event: InputEvent) -> void:
	match _mode:
		Mode.NONE: _handle_unit_select(event)
		Mode.ATTACK: _handle_attack(event)
		Mode.MOVE: _handle_move_to(event)
		_ : pass
	
	# Clear mode after action taken
	_mode = Mode.NONE

func _handle_move_to(event: InputEvent) -> void:
	_move_to(event)
	
	_mode = Mode.NONE
	
func _handle_attack(event: InputEvent) -> void:
	if not selection_manager.any_same_team:
		return
		
	# Move to location
	# First try to select a unit at the indicated location
	var result:Dictionary
	var selected_unit:Unit = node_picker.pick_unit(event)
	
	if not selected_unit:
		result = node_picker.pick_ground(event)
		
	if result or selected_unit:
		if result:
			var target_position:Vector3 = result.get("position")
			order_manager.move_and_attack(target_position)
		else:
			order_manager.attack(selected_unit)

func _handle_unit_select(event: InputEvent) -> void:
	var new_unit:Unit = node_picker.pick_unit(event)
	if new_unit:
		selection_manager.add(new_unit)
	else:
		print_debug("%s: Clear Selection" % name)
		selection_manager.clear()
	
func _on_visibility_changed() -> void:
	enabled = visible

func _on_box_select_units(_screen_selection:Rect2, ground_selection:AABB) -> void:
	var selected_units:Array[Unit] = node_picker.pick_unit_world_bounds(ground_selection)
	if selected_units:
		selection_manager.set_selection_multiple(selected_units)
