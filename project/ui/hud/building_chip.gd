class_name BuildingChip extends PanelContainer

signal clicked(type: ConstructionResource.Type)

const SCRAP_COLOR := Color(1.0, 0.9098039, 0.5294118, 1.0)
const PERSONNEL_COLOR := Color(0.5254902, 0.92941177, 0.98039216, 1.0)
const MISSING_COST_COLOR := Color(1.0, 0.47058824, 0.47058824, 1.0)


@export var resource: ConstructionResource:
	set(value):
		resource = value
		if is_node_ready():
			_apply_resource()

var _can_afford: bool = true
var _hovered: bool = false
var _count_badge_value: int = -1
var _show_count_badge: bool = true
var _show_scrap_cost: bool = true
var _show_personnel_cost: bool = true
var _show_inventory_count: bool = true
var _missing_scrap: bool = false
var _missing_personnel: bool = false
var _tooltip_code: StringName = &""
var _hud: HUD

@onready var icon: TextureRect = %BuildingIcon
@onready var name_label: Label = %BuildingName
@onready var scrap_cost: HBoxContainer = %ScrapCost
@onready var scrap_cost_icon: PanelContainer = %ScrapCostIcon
@onready var scrap_cost_value: Label = %ScrapCostValue
@onready var personnel_cost: HBoxContainer = %PersonnelCostRow
@onready var personnel_cost_icon: PanelContainer = %PersonnelCostIcon
@onready var personnel_cost_value: Label = %PersonnelCostValue
@onready var inventory_count: HBoxContainer = %InventoryCountRow
@onready var inventory_count_value: Label = %InventoryCountValue
@onready var count_badge: PanelContainer = %CountBadge
@onready var count_badge_value: Label = %CountLabel
@onready var unavailable_overlay: Control = %UnavailableOverlay

var _inventory_count: int = -1

func _ready() -> void:
	_hud = Groups.get_parent_with_type(self, HUD) as HUD
	_apply_resource()
	_set_affordability_overlay()
	_update_cost_state()
	_update_border_style()


func _apply_resource() -> void:
	if not is_node_ready():
		return

	if resource == null:
		if _hovered and _hud and _tooltip_code != StringName():
			_hud.ui_element_exited.emit(_tooltip_code)
		name_label.text = ""
		scrap_cost_value.text = "0"
		personnel_cost.visible = false
		inventory_count.visible = false
		set_missing_costs(false, false)
		_tooltip_code = &""
		if count_badge:
			count_badge.visible = false
		_update_border_style()
		return

	if resource.icon:
		icon.texture = resource.icon

	name_label.text = _type_to_display_name(resource.type)
	_tooltip_code = _type_to_tooltip_code(resource.type)
	_update_scrap_cost()
	_update_personnel_cost()
	_update_count_badge()
	_update_inventory_count()
	_set_affordability_overlay()
	_update_cost_state()
	if _hovered:
		_emit_tooltip_entered()


func set_show_count_badge(show_count_badge: bool) -> void:
	_show_count_badge = show_count_badge
	if is_node_ready():
		_update_count_badge()


func set_show_personnel_cost(show_personel_cost: bool) -> void:
	_show_personnel_cost = show_personel_cost
	if is_node_ready():
		_update_personnel_cost()


func set_show_scrap_cost(show_scrap_cost: bool) -> void:
	_show_scrap_cost = show_scrap_cost
	if is_node_ready():
		_update_scrap_cost()


func set_show_inventory_count(show_inventory_count: bool) -> void:
	_show_inventory_count = show_inventory_count
	if is_node_ready():
		_update_inventory_count()


func _update_scrap_cost():
	if not resource or resource.cost <= 0 or not _show_scrap_cost:
		scrap_cost.visible = false
		scrap_cost_value.text = "0"
	else:
		scrap_cost.visible = true
		scrap_cost_value.text = str(resource.cost)


func _update_personnel_cost():
	if not resource or resource.personnel <= 0 or not _show_personnel_cost:
		personnel_cost.visible = false
		personnel_cost_value.text = "0"
	else:
		personnel_cost.visible = true
		personnel_cost_value.text = str(resource.personnel)


func _update_count_badge() -> void:
	if not resource or resource.count <= 1 or not _show_count_badge:
		count_badge.visible = false
		count_badge_value.text = "0"
	else:
		count_badge.visible = true
		count_badge_value.text = str(resource.count)


func _update_inventory_count():
	if not _show_inventory_count:
		inventory_count.visible = false
		inventory_count_value.text = "0"
	else:
		inventory_count.visible = true
		inventory_count_value.text = str(_inventory_count)


func set_inventory_count(count: int) -> void:
	_inventory_count = count
	_update_inventory_count()


func set_can_afford(can_afford: bool) -> void:
	_can_afford = can_afford
	if is_node_ready():
		_set_affordability_overlay()
		_update_border_style()


func set_missing_costs(missing_scrap: bool, missing_personnel: bool) -> void:
	_missing_scrap = missing_scrap
	_missing_personnel = missing_personnel
	if is_node_ready():
		_update_cost_state()
		if _hovered:
			_emit_tooltip_entered()


func _gui_input(event: InputEvent) -> void:
	if resource == null:
		return
	if not _can_afford:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(resource.type)
		accept_event()


func _on_mouse_entered() -> void:
	_hovered = true
	_update_border_style()
	_emit_tooltip_entered()


func _on_mouse_exited() -> void:
	_hovered = false
	_update_border_style()
	if _hud and _tooltip_code != StringName():
		_hud.ui_element_exited.emit(_tooltip_code)


func _set_affordability_overlay() -> void:
	if not is_node_ready():
		return

	if unavailable_overlay:
		unavailable_overlay.visible = resource != null and not _can_afford


func _update_cost_state() -> void:
	if scrap_cost_value:
		scrap_cost_value.modulate = MISSING_COST_COLOR if _missing_scrap else SCRAP_COLOR
	if scrap_cost_icon:
		scrap_cost_icon.modulate = MISSING_COST_COLOR if _missing_scrap else Color.WHITE
	if personnel_cost_value:
		personnel_cost_value.modulate = MISSING_COST_COLOR if _missing_personnel else PERSONNEL_COLOR
	if personnel_cost_icon:
		personnel_cost_icon.modulate = MISSING_COST_COLOR if _missing_personnel else Color.WHITE


func _update_border_style() -> void:
	var stylebox := get_theme_stylebox("panel") as StyleBoxFlat
	if stylebox == null:
		return

	stylebox = stylebox.duplicate() as StyleBoxFlat
	if stylebox == null:
		return

	var is_highlighted := resource != null and _can_afford and _hovered
	stylebox.border_width_left = HUD.BORDER_WIDTH
	stylebox.border_width_top = HUD.BORDER_WIDTH
	stylebox.border_width_right = HUD.BORDER_WIDTH
	stylebox.border_width_bottom = HUD.BORDER_WIDTH
	stylebox.border_color = HUD.BUILDING_BORDER_COLOR if is_highlighted else HUD.DEFAULT_BORDER_COLOR
	add_theme_stylebox_override("panel", stylebox)


func get_tooltip_note() -> String:
	var reasons: Array[String] = []
	if _missing_scrap:
		reasons.push_back("Needs Scrap")
	if _missing_personnel:
		reasons.push_back("Needs Personnel")
	return ", ".join(reasons)


func _emit_tooltip_entered() -> void:
	if _hud == null or _tooltip_code == StringName():
		return
	_hud.ui_element_entered.emit(_tooltip_code, get_tooltip_note())


func _type_to_tooltip_code(type: ConstructionResource.Type) -> StringName:
	return StringName("construction_%s" % EnumUtils.enum_to_string(ConstructionResource.Type, type).to_snake_case())


func _type_to_display_name(type: ConstructionResource.Type) -> String:
	match type:
		ConstructionResource.Type.CommandCenter:
			return "Command Center"
		ConstructionResource.Type.Barracks:
			return "Barracks"
		ConstructionResource.Type.Factory:
			return "Factory"
		ConstructionResource.Type.TankSpikes:
			return "Tank Spikes"
		ConstructionResource.Type.BarbedWire:
			return "Barbed Wire"
		ConstructionResource.Type.Mine:
			return "Mine"
		ConstructionResource.Type.Turret:
			return "Turret"
		ConstructionResource.Type.Marine:
			return "Marine"
		ConstructionResource.Type.Tank:
			return "Tank"
		ConstructionResource.Type.Artillery:
			return "Artillery"
		ConstructionResource.Type.Transport:
			return "Marine Transport"
		ConstructionResource.Type.Bunker:
			return "Bunker"
		_:
			return ""
