@tool
class_name BoxSelect extends Node

signal on_box_selection(area:Rect2)

var action_name:StringName

@export
var node_picker:NodePicker

@export_range(1.0, 1e9, 1.0, "or_greater")
var min_size:float = 1.0

var selection_rect:Rect2
var pressed:bool

func _ready() -> void:
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
		selection_rect.position = mouse_event.position
		selection_rect.end = mouse_event.position
		
	if pressed and mouse_event.is_action_released(action_name, true):
		pressed = false
		selection_rect.end = mouse_event.position
		if selection_rect.size.length() >= min_size:
			print_debug("%s: on_box_selection=%s" % [name, selection_rect])
			on_box_selection.emit(selection_rect)

func _process(_delta: float) -> void:
	if not pressed or not node_picker:
		return
	
	var viewport := get_viewport()
	var mouse_pos:Vector2 = viewport.get_mouse_position()
	var current_rect:Rect2
	current_rect.position = selection_rect.position
	current_rect.end = mouse_pos
	
	var size_sq:float = current_rect.size.length_squared()
	if size_sq < min_size * min_size:
		return
	
	var size:Vector2 = current_rect.size
	#Visualize selection	
	#var center_screen:Vector2 = current_rect.get_center()
	#var result := node_picker.pick_position(center_screen, Collisions.CompositeMasks.ground)
	var result := node_picker.pick_position(current_rect.position, Collisions.CompositeMasks.ground)
	if not result:
		return
	
	#push_warning("%s: current_rect=%s" % [name, current_rect])
	DebugDraw3D.draw_box(
		result["position"],
		Quaternion.IDENTITY,
		Vector3(size.x, 5.0, size.y),
		Color.GREEN,
		false,
		0.1
	)
		
		
	
