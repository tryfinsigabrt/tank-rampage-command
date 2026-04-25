class_name PlayerNodePlacer extends Node

@export
var node_picker: NodePicker

@export
var selection_manager:SelectionManager

@onready var building_manufacturing: BuildingManufacturing = $BuildingManufacturing

var _current_placement_spawner:NodePlacementSpawner

func _ready() -> void:
	set_process(false)
	
	assert(node_picker, "node_picker not set!")
	assert(selection_manager, "selection_manager not set!")
	
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
		
	if event.is_action_pressed(&"build_command_center"):
		_current_placement_spawner = building_manufacturing.create(ConstructionResource.Type.CommandCenter)
	elif event.is_action_pressed(&"build_factory"):
		_current_placement_spawner = building_manufacturing.create(ConstructionResource.Type.Factory)
	elif event.is_action_pressed(&"build_barracks"):
		_current_placement_spawner = building_manufacturing.create(ConstructionResource.Type.Barracks)

	if _current_placement_spawner == null:
		return
	
	add_child(_current_placement_spawner)
	
	# Set initial position
	_current_placement_spawner.activate()
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
	
func _process(_delta: float) -> void:
	# This shouldn't happen as we disable process when there is no active spawner
	if not _current_placement_spawner:
		return
		
	_move_spawner()

func _move_spawner() -> bool:
	var mouse_position:Vector2 = get_viewport().get_mouse_position()
	# Project to world and then move the placement spawner
	
	var result: Dictionary = node_picker.pick_position(mouse_position, Collisions.CompositeMasks.ground)
	if not result:
		return false
		
	var position:Vector3 = result["position"]
	_current_placement_spawner.move_to(position, true)
	
	return true
