class_name GroupManager extends Node

@export
var selection_manager:SelectionManager

@export
var reselect_camera_zoom_max_time:float = 2.0

var _grouper:TeamAssetGrouper = TeamAssetGrouper.new()

var _player:Player

var _last_selected_group:String
var _last_selected_group_ticks_ms:int

func _ready() -> void:
	_player = get_tree().get_first_node_in_group(Groups.Player)
	if not _player:
		push_warning("%s: Could not find player in tree" % name)
		return
	
func _unhandled_input(event: InputEvent) -> void:
	if not selection_manager:
		return
	var key_event:InputEventKey = event as InputEventKey
	if not key_event or not key_event.pressed:
		return
		
	var key:Key = key_event.keycode
	# Only 1-0:
	if key < Key.KEY_0 or key > Key.KEY_9:
		_clear_last_selected_group()
		return

	var group:String = _get_group(key)		
	var is_assignment:bool = key_event.is_command_or_control_pressed()
	
	if is_assignment:		
		var current_selection:Array[Node3D] = selection_manager.all_selected_same_team
		if not current_selection:
			print_debug("%s: Attempted to assign selection to group %s but nothing was selected" % [name, group])
			
			_clear_last_selected_group()
			return
		_grouper.add_group(group, current_selection)
	else:
		var requested_group:Array[Node3D]
		if _grouper.has(group):
			requested_group = _grouper.get_group(group)
		if not requested_group:
			print_debug("%s: Attempted to get selection for group %s but nothing valid assigned" % [name, group])
			_clear_last_selected_group()
			return
		
		print_debug("%s: Selecting group %s: %s " % [name, group, requested_group])
		selection_manager.set_selection_multiple(requested_group)
		
	if is_assignment:
		_clear_last_selected_group()
	else:
		_handle_camera_selection_action(group)
		
	_consume_input()

static func _get_group(key: Key) -> String:
	# Make Key 0 be group "10"
	if key > Key.KEY_0:
		return "%d" % (key - Key.KEY_0)
	return "10"

func _consume_input() -> void:
	get_viewport().set_input_as_handled()

#region Double select to focus camera
func _handle_camera_selection_action(group:String) -> void:
	if not _player:
		return
		
	if _last_selected_group == group and _was_recently_selected():
		# Don't change zoom
		_player.focus_on(_grouper.get_group(group), 0)
	
	# Always refresh the time group was last selected
	_set_recently_selected_group(group)
	
func _clear_last_selected_group() -> void:
	_last_selected_group = ""
	_last_selected_group_ticks_ms = -1

func _set_recently_selected_group(group:String) -> void:
	_last_selected_group = group
	# Use wall time as we don't want to pause the interval capture
	_last_selected_group_ticks_ms = Time.get_ticks_msec()
	
func _was_recently_selected() -> bool:
	var curr_ticks_ms:int = Time.get_ticks_msec()
	var delta_time:float = (curr_ticks_ms - _last_selected_group_ticks_ms) / 1000.0
	return delta_time < reselect_camera_zoom_max_time
	
#endregion
