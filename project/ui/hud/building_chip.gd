class_name BuildingChip extends PanelContainer

signal clicked(type: ConstructionResource.Type)


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

@onready var icon: TextureRect = %BuildingIcon
@onready var name_label: Label = %BuildingName
@onready var scrap_cost: HBoxContainer = %ScrapCost
@onready var scrap_cost_value: Label = %ScrapCostValue
@onready var personnel_cost: HBoxContainer = %PersonnelCostRow
@onready var personnel_cost_value: Label = %PersonnelCostValue
@onready var inventory_count: HBoxContainer = %InventoryCountRow
@onready var inventory_count_value: Label = %InventoryCountValue
@onready var count_badge: PanelContainer = %CountBadge
@onready var count_badge_value: Label = %CountLabel
@onready var unavailable_overlay: Control = %UnavailableOverlay

var _inventory_count: int = -1

func _ready() -> void:
	_apply_resource()
	_set_affordability_overlay()
	_update_border_style()


func _apply_resource() -> void:
	if not is_node_ready():
		return

	if resource == null:
		name_label.text = ""
		scrap_cost_value.text = "0"
		personnel_cost.visible = false
		inventory_count.visible = false
		if count_badge:
			count_badge.visible = false
		_update_border_style()
		return

	if resource.icon:
		icon.texture = resource.icon

	name_label.text = _type_to_display_name(resource.type)
	_update_scrap_cost()
	_update_personnel_cost()
	_update_count_badge()
	_update_inventory_count()
	_set_affordability_overlay()


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


func _on_mouse_exited() -> void:
	_hovered = false
	_update_border_style()


func _set_affordability_overlay() -> void:
	if not is_node_ready():
		return

	if unavailable_overlay:
		unavailable_overlay.visible = resource != null and not _can_afford


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
		ConstructionResource.Type.Bunker:
			return "Bunker"
		_:
			return ""
