extends Control

signal back_requested

const COLUMN_SECTIONS := [
	[
		{
			"title": "Camera",
			"rows": [
				{"label": "Move Camera", "actions": [&"camera_move_forward", &"camera_move_backward", &"camera_move_left", &"camera_move_right"], "extra": "Screen Edge"},
				{"label": "Drag Pan Camera", "actions": [&"camera_drag_pan"]},
				{"label": "Rotate Camera", "actions": [&"camera_rotate_left", &"camera_rotate_right"]},
				{"label": "Zoom Camera", "actions": [&"camera_zoom_in", &"camera_zoom_out"]},
				{"label": "Pause", "actions": [&"pause"]},
			],
		},
		{
			"title": "Selection",
			"rows": [
				{"label": "Select / Box Select", "actions": [&"unit_select"]},
				{"label": "Toggle Select", "actions": [&"unit_multi_toggle_select"]},
				{"label": "Select Same Type", "actions": [&"unit_type_select"]},
				{"label": "Select All", "actions": [&"unit_select_all"]},
			],
		},
		{
			"title": "Orders",
			"rows": [
				{"label": "Smart Action / Move", "actions": [&"unit_smart_action"]},
				{"label": "Move", "actions": [&"unit_mode_move"]},
				{"label": "Attack", "actions": [&"unit_mode_attack"]},
				{"label": "Stop", "actions": [&"unit_mode_stop"]},
				{"label": "Hold", "actions": [&"unit_mode_hold"]},
				{"label": "Unload Occupants", "actions": [&"bunker_unload_all"]},
			],
		},
	],
	[
		{
			"title": "Construction",
			"rows": [
				{"label": "Command Center", "actions": [&"build_command_center"]},
				{"label": "Barracks", "actions": [&"build_barracks"]},
				{"label": "Factory", "actions": [&"build_factory"]},
				{"label": "Bunker", "actions": [&"build_bunker"]},
				{"label": "Turret", "actions": [&"build_turret"]},
				{"label": "Tank Spikes", "actions": [&"build_tank_spikes"]},
				{"label": "Mines", "actions": [&"build_mines"]},
				{"label": "Sandbags", "actions": [&"build_sandbags"]},
				{"label": "Place / Cancel Placement", "actions": [&"place_ghost_building", &"cancel_ghost_building"]},
				{"label": "Rotate Placement", "actions": [&"ghost_asset_rotate_ccw", &"ghost_asset_rotate_cw"]},
			],
		},
		{
			"title": "Construction Cancels",
			"rows": [
				{"label": "Cancel Tank Spikes", "actions": [&"cancel_tank_spikes"]},
				{"label": "Cancel Mines", "actions": [&"cancel_mines"]},
				{"label": "Cancel Sandbags", "actions": [&"cancel_sandbags"]},
				{"label": "Cancel Bunker", "actions": [&"cancel_bunker"]},
				{"label": "Cancel Turret", "actions": [&"cancel_turret"]},
			],
		},
		{
			"title": "Production",
			"rows": [
				{"label": "Build Marine", "actions": [&"build_marine"]},
				{"label": "Build Tank", "actions": [&"build_tank"]},
				{"label": "Build Artillery", "actions": [&"build_artillery"]},
				{"label": "Cancel Marine", "actions": [&"cancel_marine"]},
				{"label": "Cancel Tank", "actions": [&"cancel_tank"]},
				{"label": "Cancel Artillery", "actions": [&"cancel_artillery"]},
			],
		},
		{
			"title": "Rally / Other",
			"rows": [
				{"label": "Set Rally Point", "actions": [&"set_rally_point"]},
				{"label": "Clear Rally Point", "actions": [&"clear_rally_point"]},
				{"label": "Navigate Minimap", "actions": [&"mini_map_navigate"]},
				{"label": "Toggle Debug HUD", "actions": [&"toggle_debug_hud"]},
			],
		},
	],
]

const SECTION_TITLE_COLOR := Color(0.99607843, 0.9647059, 0.7019608, 1)
const KEY_COLOR := Color(0.7372549, 0.88235295, 0.7254902, 1)

@onready var left_column: VBoxContainer = %LeftColumn
@onready var right_column: VBoxContainer = %RightColumn

func _ready() -> void:
	hide()
	_populate_columns()

func _populate_columns() -> void:
	_clear_column(left_column)
	_clear_column(right_column)

	var columns := [left_column, right_column]
	for i in COLUMN_SECTIONS.size():
		var column: Variant = columns[i]
		for section_data in COLUMN_SECTIONS[i]:
			column.add_child(_create_section(section_data))

func _clear_column(column: VBoxContainer) -> void:
	for child in column.get_children():
		child.queue_free()

func _create_section(section_data: Dictionary) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = section_data.get("title", "")
	title.add_theme_color_override("font_color", SECTION_TITLE_COLOR)
	title.add_theme_font_size_override("font_size", 30)
	container.add_child(title)

	for row_data in section_data.get("rows", []):
		container.add_child(_create_row(row_data))

	return container

func _create_row(row_data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var description := Label.new()
	description.text = row_data.get("label", "")
	description.custom_minimum_size = Vector2(260, 0)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 24)
	row.add_child(description)

	var binding := Label.new()
	binding.text = _format_binding_text(row_data)
	binding.custom_minimum_size = Vector2(220, 0)
	binding.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	binding.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	binding.add_theme_color_override("font_color", KEY_COLOR)
	binding.add_theme_font_size_override("font_size", 24)
	row.add_child(binding)

	return row

func _format_binding_text(row_data: Dictionary) -> String:
	var values: Array[String] = []
	for action_name: StringName in row_data.get("actions", []):
		for binding in _get_action_bindings(action_name):
			if binding not in values:
				values.push_back(binding)

	var extra := row_data.get("extra", "") as String
	if not extra.is_empty() and extra not in values:
		values.push_back(extra)

	return " / ".join(values)

func _get_action_bindings(action_name: StringName) -> Array[String]:
	var bindings: Array[String] = []
	for event in InputMap.action_get_events(action_name):
		var text := _format_input_event(event)
		if not text.is_empty():
			bindings.push_back(text)
	return bindings

func _format_input_event(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return _format_mouse_event(event)
	if event is InputEventKey:
		return _format_key_event(event)
	return ""

func _format_mouse_event(event: InputEventMouseButton) -> String:
	var parts: Array[String] = _modifier_parts(event.shift_pressed, event.ctrl_pressed, event.alt_pressed, event.meta_pressed)
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			parts.push_back("Left Click")
		MOUSE_BUTTON_RIGHT:
			parts.push_back("Right Click")
		MOUSE_BUTTON_MIDDLE:
			parts.push_back("Middle Mouse")
		MOUSE_BUTTON_WHEEL_UP:
			parts.push_back("Wheel Up")
		MOUSE_BUTTON_WHEEL_DOWN:
			parts.push_back("Wheel Down")
		_:
			parts.push_back("Mouse %d" % event.button_index)
	return " + ".join(parts)

func _format_key_event(event: InputEventKey) -> String:
	var parts: Array[String] = _modifier_parts(event.shift_pressed, event.ctrl_pressed, event.alt_pressed, event.meta_pressed)
	var key_text := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode))
	if key_text.is_empty():
		key_text = OS.get_keycode_string(event.keycode)
	parts.push_back(key_text)
	return " + ".join(parts)

func _modifier_parts(shift_pressed: bool, ctrl_pressed: bool, alt_pressed: bool, meta_pressed: bool) -> Array[String]:
	var parts: Array[String] = []
	if ctrl_pressed:
		parts.push_back("Ctrl")
	if shift_pressed:
		parts.push_back("Shift")
	if alt_pressed:
		parts.push_back("Alt")
	if meta_pressed:
		parts.push_back("Meta")
	return parts

func _on_back_button_pressed() -> void:
	back_requested.emit()
