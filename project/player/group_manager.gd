class_name GroupManager extends Node

@export
var selection_manager:SelectionManager

var _grouper:TeamAssetGrouper = TeamAssetGrouper.new()

func _unhandled_input(event: InputEvent) -> void:
	if not selection_manager:
		return
	var key_event:InputEventKey = event as InputEventKey
	if not key_event or not key_event.pressed:
		return
		
	var key:Key = key_event.keycode
	# Only 1-0:
	if key < Key.KEY_0 or key > Key.KEY_9:
		return

	var group:String = _get_group(key)		
	var is_assignment:bool = key_event.is_command_or_control_pressed()
	
	if is_assignment:
		var current_selection:Array[Node3D] = selection_manager.all_selected_same_team
		if not current_selection:
			print_debug("%s: Attempted to assign selection to group %s but nothing was selected" % [name, group])
			return
		_grouper.add_group(group, current_selection)
	else:
		var requested_group:Array[Node3D]
		if _grouper.has(group):
			requested_group = _grouper.get_group(group)
		if not requested_group:
			print_debug("%s: Attempted to get selection for group %s but nothing valid assigned" % [name, group])
			return
		
		print_debug("%s: Selecting group %s: %s " % [name, group, requested_group])
		selection_manager.set_selection_multiple(requested_group)
		
	_consume_input()

static func _get_group(key: Key) -> String:
	# Make Key 0 be group "10"
	if key > Key.KEY_0:
		return "%d" % (key - Key.KEY_0)
	return "10"

func _consume_input() -> void:
	get_viewport().set_input_as_handled()
