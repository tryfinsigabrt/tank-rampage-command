class_name TooltipLayer extends Control

const SHOW_DELAY: float = 0.2
const HIDE_DELAY: float = 0.2
const STILLNESS_DISTANCE_THRESHOLD: float = 3.0
const TOOLTIP_OFFSET: Vector2 = Vector2(18.0, 18.0)

@onready var tooltip_view: TooltipView = %TooltipView

var _tooltip_data_by_code: Dictionary = {
		&"construction_command_center": {
			"title": "Command Center",
			"subtitle": "Building",
			"content": "Allows building battlefield control structures. \nWhen placed above a Scrap field it will extract Scrap over time.",
		},
		&"construction_barracks": {
			"title": "Barracks",
			"subtitle": "Building",
			"content": "Allows training new infantry units.",
		},
		&"construction_factory": {
			"title": "Factory",
			"subtitle": "Building",
			"content": "Allows building armored fighting units and transport units.",
		},
		&"construction_tank_spikes": {
			"title": "Tank Spikes",
			"subtitle": "Structure",
			"content": "Place tank spikes from the Inventory to obstruct movement to all vehicles.",
		},
		&"construction_barbed_wire": {
			"title": "Barbed Wire",
			"subtitle": "Structure",
			"content": "Place barbed wire from the Inventory to obstruct movement to all infantry.",
		},
		&"construction_mine": {
			"title": "Mine",
			"subtitle": "Structure",
			"content": "Place mines from the Inventory which explode when enemy units cross over them.",
		},
		&"construction_turret": {
			"title": "Turret",
			"subtitle": "Structure",
			"content": "Place turrets from the Inventory to defend a position from enemy units.",
		},
		&"construction_marine": {
			"title": "Marine",
			"subtitle": "Unit",
			"content": "Basic infantry unit, versitile and cheap, but with low health and damage.",
		},
		&"construction_tank": {
			"title": "Tank",
			"subtitle": "Unit",
			"content": "Armored fighting unit, fast and highly damaging, but expensive.",
		},
		&"construction_artillery": {
			"title": "Artillery",
			"subtitle": "Unit",
			"content": "Long distance, high damage but slow and vulnerable to close range enemy units.",
		},
		&"construction_transport": {
			"title": "Marine Transport",
			"subtitle": "Unit",
			"content": "Transport truck can be used to quickly move marine units across large distances.",
		},
		&"construction_bunker": {
			"title": "Bunker",
			"subtitle": "Structure",
			"content": "Defensive structure can be placed from the Inventory, can be populated by marines to give them protection while defending from enemy.",
		},
	}
	
	
	
var _current_hover_code: StringName = &""
var _current_extra: String = ""
var _visible_code: StringName = &""
var _tooltip_hovered: bool = false
var _mouse_stationary_time: float = 0.0
var _hide_time_remaining: float = -1.0
var _last_mouse_position: Vector2 = Vector2.INF


func _ready() -> void:
	tooltip_view.hide()
	tooltip_view.mouse_entered.connect(_on_tooltip_mouse_entered)
	tooltip_view.mouse_exited.connect(_on_tooltip_mouse_exited)
	_last_mouse_position = get_viewport().get_mouse_position()
	var hud := get_parent() as HUD
	if not hud:
		push_error("TooltipLayer must be a child of HUD.")
		return
	
	
	hud.ui_element_entered.connect(_on_ui_element_entered)
	hud.ui_element_exited.connect(_on_ui_element_exited)


func _process(delta: float) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	if _last_mouse_position == Vector2.INF:
		_last_mouse_position = mouse_position

	if mouse_position.distance_to(_last_mouse_position) <= STILLNESS_DISTANCE_THRESHOLD:
		_mouse_stationary_time += delta
	else:
		_mouse_stationary_time = 0.0

	if _hide_time_remaining >= 0.0:
		_hide_time_remaining -= delta
		if _hide_time_remaining <= 0.0 and not _tooltip_hovered:
			_hide_tooltip()

	if not _current_hover_code.is_empty() and not tooltip_view.visible and _mouse_stationary_time >= SHOW_DELAY:
		_show_tooltip(_current_hover_code)

	_last_mouse_position = mouse_position


func _on_ui_element_entered(code: StringName, extra: String) -> void:
	if code == StringName():
		return

	if tooltip_view.visible and _visible_code != code:
		_hide_tooltip()

	_current_hover_code = code
	_current_extra = extra
	_mouse_stationary_time = 0.0
	_hide_time_remaining = -1.0

	if tooltip_view.visible and _visible_code == code:
		_show_tooltip(code)


func _on_ui_element_exited(code: StringName) -> void:
	if code != _current_hover_code:
		return

	_current_hover_code = StringName()
	_current_extra = ""
	_mouse_stationary_time = 0.0
	if tooltip_view.visible and not _tooltip_hovered:
		_hide_time_remaining = HIDE_DELAY


func _on_tooltip_mouse_entered() -> void:
	_tooltip_hovered = true
	_hide_time_remaining = -1.0


func _on_tooltip_mouse_exited() -> void:
	_tooltip_hovered = false
	if _current_hover_code == StringName():
		_hide_time_remaining = HIDE_DELAY


func _show_tooltip(code: StringName) -> void:
	var tooltip_data: Dictionary = _tooltip_data_by_code.get(code, {})
	if tooltip_data.is_empty():
		return

	tooltip_view.set_tooltip_data(tooltip_data, _current_extra)
	tooltip_view.show()
	_visible_code = code
	_place_tooltip()


func _hide_tooltip() -> void:
	tooltip_view.hide()
	_visible_code = &""
	_hide_time_remaining = -1.0


func _place_tooltip() -> void:
	var tooltip_size := tooltip_view.get_display_size()
	tooltip_view.size = tooltip_size

	var hud_rect := get_global_rect()
	var mouse_position := get_viewport().get_mouse_position()

	var preferred_x := mouse_position.x + TOOLTIP_OFFSET.x
	if preferred_x + tooltip_size.x > hud_rect.end.x:
		preferred_x = mouse_position.x - TOOLTIP_OFFSET.x - tooltip_size.x
	preferred_x = clampf(preferred_x, hud_rect.position.x, hud_rect.end.x - tooltip_size.x)

	var preferred_y := mouse_position.y + TOOLTIP_OFFSET.y
	if preferred_y + tooltip_size.y > hud_rect.end.y:
		preferred_y = mouse_position.y - TOOLTIP_OFFSET.y - tooltip_size.y
	preferred_y = clampf(preferred_y, hud_rect.position.y, hud_rect.end.y - tooltip_size.y)

	tooltip_view.global_position = Vector2(preferred_x, preferred_y)
