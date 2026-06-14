class_name PlayerNodePlacer extends Node

@export
var node_picker: NodePicker

@export
var selection_manager:SelectionManager

@export
var stationary_refresh_interval:float = 0.2

@export
var rotation_rate_degrees:float = 45.0

@onready var building_manufacturing: BuildingManufacturing = $BuildingManufacturing

var _inventory_component:InventoryComponent

var _current_placement_spawner:NodePlacementSpawner
var _last_mouse_position:Vector2
var _last_mouse_dt:float

func _ready() -> void:
	set_process(false)
	SignalBus.on_construction_requested.connect(_on_construction_requested)
	
	assert(node_picker, "node_picker not set!")
	assert(selection_manager, "selection_manager not set!")
	
	var match_team:MatchTeam = Groups.get_parent_with_type(self, MatchTeam)
	assert(match_team, "Not in a MatchTeam tree!")
	if match_team:
		await NodeUtils.ensure_ready(match_team)
		_inventory_component = match_team.inventory_component

func _exit_tree() -> void:
	if SignalBus.on_construction_requested.is_connected(_on_construction_requested):
		SignalBus.on_construction_requested.disconnect(_on_construction_requested)

func _on_construction_requested(type: ConstructionResource.Type) -> void:
	_begin_placement(type)
	
func _unhandled_input(event: InputEvent) -> void:
	if _current_placement_spawner:
		if event.is_action_pressed(&"place_ghost_building"):
			if _current_placement_spawner.spawn():
				_remove_spawner()
				_consume_input()
		elif event.is_action_pressed(&"cancel_ghost_building"):
			_remove_spawner()
			_consume_input()
		return
	
	# Don't allow building if there is an active selection
	if selection_manager.any:
		return
	
	# TODO: Can map these via resource config rather than hardcoded constants and handlers	
	if event.is_action_pressed(&"build_command_center"):
		_begin_placement(ConstructionResource.Type.CommandCenter)
	elif event.is_action_pressed(&"build_factory"):
		_begin_placement(ConstructionResource.Type.Factory)
	elif event.is_action_pressed(&"build_barracks"):
		_begin_placement(ConstructionResource.Type.Barracks)
	elif event.is_action_pressed(&"build_mines"):
		_begin_placement(ConstructionResource.Type.Mine)
	elif event.is_action_pressed(&"build_sandbags"):
		_begin_placement(ConstructionResource.Type.BarbedWire)
	elif event.is_action_pressed(&"build_tank_spikes"):
		_begin_placement(ConstructionResource.Type.TankSpikes)
	elif event.is_action_pressed(&"build_bunker"):
		_begin_placement(ConstructionResource.Type.Bunker)
	elif event.is_action_pressed(&"build_turret"):
		_begin_placement(ConstructionResource.Type.Turret)	
func _begin_placement(type: ConstructionResource.Type) -> void:
	if _current_placement_spawner:
		_remove_spawner()

	if selection_manager.any:
		selection_manager.clear()

	match type:
		ConstructionResource.Type.CommandCenter, ConstructionResource.Type.Barracks, ConstructionResource.Type.Factory:
			_current_placement_spawner = building_manufacturing.create(type)
		ConstructionResource.Type.Mine, ConstructionResource.Type.BarbedWire, ConstructionResource.Type.TankSpikes, ConstructionResource.Type.Bunker, ConstructionResource.Type.Turret:
			_current_placement_spawner = _inventory_component.create(type)
		_:
			_current_placement_spawner = null

	if _current_placement_spawner == null:
		return

	add_child(_current_placement_spawner)

	# Set initial position
	_current_placement_spawner.activate()
	_last_mouse_position = Vector2.INF
	if not _move_spawner():
		var camera := get_viewport().get_camera_3d()
		if camera:
			_current_placement_spawner.move_to(camera.global_position, false)

	set_process(true)
	
func _consume_input() -> void:
	get_viewport().set_input_as_handled()
	
func _remove_spawner() -> void:
	_current_placement_spawner.queue_free()
	_current_placement_spawner = null
	set_process(false)
	
func _process(delta: float) -> void:
	# This shouldn't happen as we disable process when there is no active spawner
	if not _current_placement_spawner:
		return
		
	_move_spawner(delta)
	
	if Input.is_action_pressed(&"ghost_asset_rotate_ccw"):
		_current_placement_spawner.rotate_yaw_deg(delta * rotation_rate_degrees)
	if Input.is_action_pressed(&"ghost_asset_rotate_cw"):
		_current_placement_spawner.rotate_yaw_deg(-delta * rotation_rate_degrees)

func _move_spawner(delta:float = 0.0) -> bool:
	_last_mouse_dt += delta	
	var mouse_position:Vector2 = get_viewport().get_mouse_position()
	# Project to world and then move the placement spawner
	# Skip if haven't moved recently - need to refresh occassionally as FOW is changing
	if _last_mouse_dt < stationary_refresh_interval and mouse_position.is_equal_approx(_last_mouse_position):
		return true
	
	_last_mouse_dt = 0.0
	_last_mouse_position = mouse_position
	var result: Dictionary = node_picker.pick_position(mouse_position)
	if not result:
		return false
		
	var position:Vector3 = result["position"]
	# Trying to optimize with true causes spurious collision issues
	# Most likely from angled camera
	_current_placement_spawner.move_to(position, false)
	
	return true
