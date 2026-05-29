class_name BuildingChip extends PanelContainer

signal clicked(type: ConstructionResource.Type)

const BUILDABLE_BORDER_COLOR := Color(0.59607846, 0.4117647, 0.06666667, 1)
const DEFAULT_BORDER_COLOR := Color(0.13333334, 0.1254902, 0.12156863, 1)
const BORDER_WIDTH := 4

@export var resource: ConstructionResource:
	set(value):
		resource = value
		if is_node_ready():
			_apply_resource()

var _can_afford: bool = true
var _hovered: bool = false

@onready var icon: TextureRect = %BuildingIcon
@onready var name_label: Label = %BuildingName
@onready var scrap_cost_value: Label = %ScrapCostValue
@onready var personnel_cost: HBoxContainer = %PersonnelCostRow
@onready var personnel_cost_value: Label = %PersonnelCostValue
@onready var unavailable_overlay: Control = %UnavailableOverlay

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
		if personnel_cost:
			personnel_cost.visible = false
		_update_border_style()
		return

	if resource.icon:
		icon.texture = resource.icon

	name_label.text = _type_to_display_name(resource.type)
	scrap_cost_value.text = str(resource.cost)
	if personnel_cost:
		personnel_cost.visible = resource.personnel > 0
	if personnel_cost_value:
		personnel_cost_value.text = str(resource.personnel)
	_set_affordability_overlay()

func set_can_afford(can_afford: bool) -> void:
	_can_afford = can_afford
	if is_node_ready():
		_set_affordability_overlay()
		_update_border_style()

func _gui_input(event: InputEvent) -> void:
	if resource == null:
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
	stylebox.border_width_left = BORDER_WIDTH
	stylebox.border_width_top = BORDER_WIDTH
	stylebox.border_width_right = BORDER_WIDTH
	stylebox.border_width_bottom = BORDER_WIDTH
	stylebox.border_color = BUILDABLE_BORDER_COLOR if is_highlighted else DEFAULT_BORDER_COLOR
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
		_:
			return ""
