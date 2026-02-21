@tool
class_name BoxSelect extends Node

signal on_box_selection(screen_selection:Rect2, ground_selection:AABB)

var action_name:StringName

@export
var node_picker:NodePicker

@export_range(1.0, 1e9, 1.0, "or_greater")
var min_size:float = 1.0

var selection_rect_screen:Rect2
var selection_bounds:AABB
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
		selection_bounds = AABB()
		selection_rect_screen.position = mouse_event.position
		#print_debug("%s: on_box_selection begin: pos=%s" % [name, mouse_event.position])

		selection_rect_screen.end = mouse_event.position
		
	if pressed and mouse_event.is_action_released(action_name, true):
		pressed = false
		selection_rect_screen.end = mouse_event.position
		if selection_rect_screen.size.length() >= min_size:
			print_debug("%s: on_box_selection: screen=%s; bounds=%s" % [name, selection_rect_screen, selection_bounds])
			on_box_selection.emit(selection_rect_screen, selection_bounds)

func _process(_delta: float) -> void:
	if not pressed or not node_picker:
		return
	
	if selection_bounds == AABB():
		var result := _pick_ground(selection_rect_screen.position)
		if result:
			selection_bounds.position = result["position"]
	else:
		var viewport := get_viewport()
		var mouse_pos:Vector2 = viewport.get_mouse_position()
		var result := _pick_ground(mouse_pos)
		if result:
			selection_bounds.end = result["position"]
			
			var size:Vector3 = selection_bounds.size
			var planar_length:Vector2 = Vector2(size.x, size.z)
			if planar_length.length_squared() >= min_size * min_size:
				DebugDraw3D.draw_box(
					selection_bounds.position,
					Quaternion.IDENTITY,
					Vector3(size.x, maxf(size.y,5.0), size.z),
					Color.GREEN,
					false,
					0.0
				)
			
func _pick_ground(screen_pos:Vector2) -> Dictionary:
	return node_picker.pick_position(screen_pos, Collisions.CompositeMasks.ground)
	
