class_name BuildingChip extends PanelContainer

@export var resource: ConstructionResource:
	set(value):
		resource = value
		if is_node_ready():
			_apply_resource()

var _can_afford: bool = true

@onready var icon: TextureRect = %BuildingIcon
@onready var name_label: Label = %BuildingName
@onready var scrap_cost_value: Label = %ScrapCostValue
@onready var personnel_cost: HBoxContainer = %PersonnelCostRow
@onready var personnel_cost_value: Label = %PersonnelCostValue
@onready var unavailable_overlay: Control = %UnavailableOverlay

func _ready() -> void:
	_apply_resource()
	_set_affordability_overlay()

func _apply_resource() -> void:
	if not is_node_ready():
		return

	if resource == null:
		name_label.text = ""
		scrap_cost_value.text = "0"
		if personnel_cost:
			personnel_cost.visible = false
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

func _set_affordability_overlay() -> void:
	if not is_node_ready():
		return

	if unavailable_overlay:
		unavailable_overlay.visible = resource != null and not _can_afford

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
