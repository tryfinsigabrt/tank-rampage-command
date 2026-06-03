extends PanelContainer

const BUILDING_CHIP_SCENE := preload("res://ui/hud/building_chip.tscn")

@export var construction_resources: Array[ConstructionResource]
@export var inventory_resources: ManufacturingTypes

@onready var construction_grid: GridContainer = %ConstructionGrid
@onready var inventory_grid: GridContainer = %InventoryGrid

var _match_team: MatchTeam
var _inventory_component: InventoryComponent

func _ready() -> void:
	_populate_construction_chips()
	_bind_team_context()
	_refresh_inventory_chips()

func _bind_team_context() -> void:
	var player := get_tree().get_first_node_in_group(Groups.Player) as Player
	if not player:
		push_error("[HUD] Cannot get Player!")
		_update_construction_affordability()
		return

	_match_team = player.player_team
	if not _match_team:
		push_error("[HUD] Player is missing Match Team!")
		_update_construction_affordability()
		return

	_inventory_component = _match_team.inventory_component
	if not _inventory_component:
		push_error("[HUD] Match team is missing Inventory Component!")
		_update_construction_affordability()
		return

	if _match_team.resources == null:
		push_error("[HUD] Match team is missing Resources!")
		return

	_update_construction_affordability()
	_refresh_inventory_chips()

	_inventory_component.inventory_changed.connect(_refresh_inventory_chips)

	var scrap := _match_team.resources.scrap
	scrap.count_changed.connect(_on_team_resources_changed)

	var personnel := _match_team.resources.personnel
	personnel.count_changed.connect(_on_team_resources_changed)
	personnel.cap_changed.connect(_on_team_resources_changed)
	personnel.queued_count_changed.connect(_on_team_resources_changed)


func _on_team_resources_changed(_old := 0, _new := 0) -> void:
	_update_construction_affordability()


func _populate_construction_chips() -> void:
	var chips := _get_construction_chips()
	for i in chips.size():
		var chip := chips[i]
		var resource := construction_resources[i] if i < construction_resources.size() else null
		chip.set_show_count_badge(false)
		chip.set_show_personnel_cost(true)
		chip.set_show_scrap_cost(true)
		chip.set_show_inventory_count(false)
		chip.resource = resource
		chip.visible = resource != null

	_update_construction_affordability()


func _connect_chip_signals(chips: Array[BuildingChip]) -> void:
	for chip in chips:
		if not chip.clicked.is_connected(_on_chip_clicked):
			chip.clicked.connect(_on_chip_clicked)


func _refresh_inventory_chips() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()

	for resource in _get_inventory_catalog():
		if resource == null:
			continue

		var type := resource.type
		var count := _inventory_component.get_count(type)

		var chip := BUILDING_CHIP_SCENE.instantiate() as BuildingChip
		inventory_grid.add_child(chip)
		chip.set_show_count_badge(false)
		chip.set_show_personnel_cost(false)
		chip.set_show_scrap_cost(false)
		chip.set_show_inventory_count(true)
		chip.resource = resource
		chip.set_inventory_count(count)
		chip.set_can_afford(count > 0)
		if not chip.clicked.is_connected(_on_chip_clicked):
			chip.clicked.connect(_on_chip_clicked)


func _on_chip_clicked(type: ConstructionResource.Type) -> void:
	SignalBus.on_construction_requested.emit(type)


func _update_construction_affordability() -> void:
	var resources := _match_team.resources if _match_team else null
	for chip in _get_construction_chips():
		var can_afford := chip.resource != null and chip.resource.can_build(resources)
		chip.set_can_afford(can_afford)


func _get_construction_chips() -> Array[BuildingChip]:
	var chips: Array[BuildingChip] = []
	for child in construction_grid.get_children():
		var chip := child as BuildingChip
		if chip:
			chips.push_back(chip)
	_connect_chip_signals(chips)
	return chips


func _get_inventory_catalog() -> Array[ConstructionResource]:
	if inventory_resources == null:
		return []
	return inventory_resources.types
