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
	ATTACK,
	STOP,
	HOLD
}

var _mode:Mode = Mode.NONE

@onready var node_picker: NodePicker = $NodePicker
@onready var selection_manager: SelectionManager = $SelectionManager
@onready var order_manager: OrderManager = $OrderManager
@onready var building_manufacturing_actions: BuildingManufacturingActions = $BuildingManufacturingActions

var enabled:bool:
	get: return is_processing_unhandled_input()
	set(value):
		set_process_unhandled_input(value)
		
func _ready() -> void:
	selection_manager.team = team
	
	if is_visible_in_tree():
		enabled = true
		
func _check_for_mode(event: InputEvent) -> bool:
	if not selection_manager.any_units:
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
	elif event.is_action_pressed("unit_mode_stop"):
		if _mode != Mode.STOP:
			_mode = Mode.STOP
			_handle_stop(event)
			get_viewport().set_input_as_handled()
			return true
	elif event.is_action_pressed("unit_mode_hold"):
		if _mode != Mode.HOLD:
			_mode = Mode.HOLD
			_handle_hold(event)
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
		_handle_toggle_asset(event)
	elif event.is_action_pressed("unit_type_select", false, true):
		_handle_select_all_of_type(event)
	elif event.is_action_pressed("unit_select_all", false, true):
		_handle_select_all(event)
		
	# This is the context-aware "right click" mode that doesn't take _mode into account	
	# Attacks unit if selects an enemy unit, follows an ally unit
	elif event.is_action_pressed("unit_move_to"):
		_handle_context_action(event)
	
func _handle_toggle_asset(event: InputEvent) -> void:
	var team_asset:Node3D = node_picker.pick_team_asset(event)
	if not team_asset:
		return
		
	var team_component:TeamComponent = TeamComponent.get_component(team_asset)
	if team_component and team_component.is_visible_to(team):
		selection_manager.toggle(team_asset)

func _handle_select_all_of_type(event: InputEvent) -> void:
	# Also currently only works on units and not buildings
	var unit := node_picker.pick_unit(event)
	if not unit:
		return
	selection_manager.set_selection_multiple(unit.get_all_units_same_team_and_class())

func _handle_select_all(event: InputEvent) -> void:
	# Only select army and not buildings and only player's team
	var unit := node_picker.pick_unit(event)
	if not unit:
		return
		
	var team_component:TeamComponent =  TeamComponent.get_component(unit)
	if team_component and team_component.is_on_team(team):
		selection_manager.set_selection_multiple(unit.get_all_units_on_same_team())
		
func _handle_context_action(event: InputEvent) -> void:
	var selected:Node3D = node_picker.pick_team_asset(event)
	if selected:
		if selected.team_component.is_on_team(team):
			# TODO: Follow not currently implemented so just move to
			_move_to(event)
		else:
			order_manager.attack(selected)
	else:
		_move_to(event)
	
func _can_issue_orders_to_unit(unit: Unit) -> bool:
	return unit and unit.team == team
	
func _move_to(event: InputEvent) -> void:
	if not selection_manager.any_units_same_team:
		return
		
	var result := node_picker.pick_ground(event)
	if not result:
		return
				
	var move_to_position:Vector3 = result.get("position")
	order_manager.move(move_to_position)
	
func _handle_select(event: InputEvent) -> void:
	match _mode:
		Mode.NONE: _handle_asset_select(event)
		Mode.ATTACK: _handle_attack(event)
		Mode.MOVE: _handle_move_to(event)
		_ : pass
	
	# Clear mode after action taken
	_mode = Mode.NONE

func _handle_move_to(event: InputEvent) -> void:
	_move_to(event)
	
	_mode = Mode.NONE
	
func _handle_stop(_event: InputEvent) -> void:
	order_manager.stop()
	
	_mode = Mode.NONE
	
func _handle_hold(_event: InputEvent) -> void:
	order_manager.hold()
	
	_mode = Mode.NONE
	
func _handle_attack(event: InputEvent) -> void:
	if not selection_manager.any_units_same_team:
		return
		
	# Move to location
	# First try to select a unit at the indicated location
	var result:Dictionary
	var selected:Node3D = node_picker.pick_team_asset(event)
	
	if not selected or not selected.team_component.is_visible_to(team):
		result = node_picker.pick_ground(event)
		
	if result or selected:
		if result:
			var target_position:Vector3 = result.get("position")
			# try to attack the position and if the selection doesn't support then fallback to move and attack
			# TODO: Think through RTS standards on this one but if we have an artillery we want it to lay down fire
			# on the targeted position rather than moving and then trying to attack units directly.
			# Only if a specific unit is targeted do we want to try and track and follow it
			if not order_manager.attack_position(target_position):
				order_manager.move_and_attack(target_position)
		else:
			order_manager.attack(selected)

func _handle_asset_select(event: InputEvent) -> void:
	# Selecting individual team asset clears previous selection
	selection_manager.clear()
	var team_asset:Node3D = node_picker.pick_team_asset(event)
	if not team_asset:
		return
		
	var team_component:TeamComponent = TeamComponent.get_component(team_asset)
	if team_component and team_component.is_visible_to(team):
		selection_manager.add(team_asset)
	
func _on_visibility_changed() -> void:
	enabled = visible

func _on_box_select_units(screen_selection:Rect2) -> void:
	# Box select only should select units
	var selected_units:Array[Unit] = node_picker.pick_unit_screen_area(screen_selection)
	if selected_units:
		selection_manager.set_selection_multiple(selected_units)
