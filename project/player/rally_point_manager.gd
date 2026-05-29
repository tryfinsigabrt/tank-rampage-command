class_name RallyPointManager extends Node

@export
var node_picker:NodePicker

@export
var selection_manager:SelectionManager

func _ready() -> void:
	assert(node_picker, "%s: Node Picker not set!" % name)
	assert(selection_manager, "%s: Selection Manager not set!" % name)
	
	if not node_picker or not selection_manager:
		queue_free()
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"clear_rally_point"):
		_clear_rally_point()
	elif event.is_action_pressed(&"set_rally_point"):
		_set_rally_point_to_mouse_cursor()

func _get_selected_building_rally_point_components() -> Array[RallyPointComponent]:
	var selected_buildings:Array[Building] = selection_manager.selected_buildings
	var rally_point_components:Array[RallyPointComponent]
	
	for building in selected_buildings:
		if selection_manager.is_on_same_team(building):
			var rally_point_comp := RallyPointComponent.get_component(building, false)
			if rally_point_comp:
				rally_point_components.push_back(rally_point_comp)
				
	return rally_point_components

func _clear_rally_point() -> void:
	var selected_rally_points := _get_selected_building_rally_point_components()
	if not selected_rally_points:
		return
		
	print_debug("%s: Clear rally point for %s" % [name, selected_rally_points])
	for rally_point in selected_rally_points:
		rally_point.clear_rally_point()
	
func _set_rally_point_to_mouse_cursor() -> void:
	var selected_rally_points := _get_selected_building_rally_point_components()
	if not selected_rally_points:
		return
		
	var viewport := get_viewport()
	var mouse_pos:Vector2 = viewport.get_mouse_position()
	
	var result:Dictionary = node_picker.pick_position(mouse_pos)
	if not result:
		print_debug("%s: Could not set rally point as ground not found at cursor pos:%s" % [name, mouse_pos])
		return
	
	var ground_pos:Vector3 = result["position"]
	
	print_debug("%s: Set rally point to %s for %s" % [name, ground_pos, selected_rally_points])

	for rally_point in selected_rally_points:
		rally_point.rally_point = ground_pos
