@tool
class_name BoxSelect extends Node

signal on_box_selection(screen_selection:Rect2)

var action_name:StringName

@export
var node_picker:NodePicker

@export_range(1.0, 1e9, 1.0, "or_greater")
var min_size:float = 1.0

var selection_rect_screen:Rect2

var pressed:bool:
	set(value):
		pressed = value
		set_process(value and node_picker)

@onready 
var box_render: BoxRender = %BoxRender

func _ready() -> void:
	set_process(false)
	
	if not action_name:
		push_error("%s: action_name is not set!" % name)
		
# Display action_name as a drop down - requires the class have @tool
func _get_property_list() -> Array[Dictionary]:
	return [EditorUtils.get_input_actions_selection_property("action_name")]

func _unhandled_input(event: InputEvent) -> void:
	var mouse_event:InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event:
		return
		
	if not pressed and mouse_event.is_action_pressed(action_name, false, true):
		pressed = true
		selection_rect_screen.position = mouse_event.position
		selection_rect_screen.end = mouse_event.position
		
	if pressed and mouse_event.is_action_released(action_name, true):
		box_render.hide()
		pressed = false
		selection_rect_screen.end = mouse_event.position
		if is_minimum_size_selection():
			# If invert he box then the size components are neg so need to take the absolute value
			selection_rect_screen = selection_rect_screen.abs()
			on_box_selection.emit(selection_rect_screen)

func is_minimum_size_selection() -> bool:
	return selection_rect_screen.size.length() >= min_size

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	var viewport := get_viewport()
	var mouse_pos:Vector2 = viewport.get_mouse_position()
	selection_rect_screen.end = mouse_pos
	
	if is_minimum_size_selection():
		box_render.display(selection_rect_screen)
	else:
		box_render.hide()
