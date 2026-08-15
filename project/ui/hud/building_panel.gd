extends PanelContainer

@onready var build_row: HBoxContainer = %BuildRow
@onready var queue_row: HBoxContainer = %QueueRow
@onready var queue_info: VBoxContainer = %QueueInfo

var _selection_manager: SelectionManager
var _current_building: Building
var _current_manufacturing: ManufacturingComponent


func _ready() -> void:
	visible = false
	_connect_selection_sources()
	_connect_chip_signals()
	_connect_queue_slot_signals()
	_refresh_selected_building()


func _process(_delta: float) -> void:
	if _current_manufacturing == null or _current_building == null:
		return

	_populate_queue_row()


func _exit_tree() -> void:
	_disconnect_selection_signals()
	_disconnect_manufacturing_signals()


func _connect_selection_sources() -> void:
	var player := get_tree().get_first_node_in_group(Groups.Player) as Player
	if player:
		_selection_manager = player.player_unit_actions.selection_manager

	SignalBus.on_building_selected.connect(_on_selection_changed)
	SignalBus.on_building_deselected.connect(_on_selection_changed)
	SignalBus.on_unit_selected.connect(_on_selection_changed)
	SignalBus.on_unit_deselected.connect(_on_selection_changed)


func _disconnect_selection_signals() -> void:
	if SignalBus.on_building_selected.is_connected(_on_selection_changed):
		SignalBus.on_building_selected.disconnect(_on_selection_changed)
	if SignalBus.on_building_deselected.is_connected(_on_selection_changed):
		SignalBus.on_building_deselected.disconnect(_on_selection_changed)
	if SignalBus.on_unit_selected.is_connected(_on_selection_changed):
		SignalBus.on_unit_selected.disconnect(_on_selection_changed)
	if SignalBus.on_unit_deselected.is_connected(_on_selection_changed):
		SignalBus.on_unit_deselected.disconnect(_on_selection_changed)


func _connect_chip_signals() -> void:
	for chip in _get_build_chips():
		if not chip.clicked.is_connected(_on_chip_clicked):
			chip.clicked.connect(_on_chip_clicked)


func _connect_queue_slot_signals() -> void:
	var slots := _get_queue_slots()
	for i in slots.size():
		var slot := slots[i]
		slot.slot_index = i
		if not slot.clicked.is_connected(_on_queue_slot_clicked):
			slot.clicked.connect(_on_queue_slot_clicked)


func _on_selection_changed(_asset: Node3D) -> void:
	_refresh_selected_building()


func _refresh_selected_building() -> void:
	if _selection_manager == null:
		_hide_panel()
		return

	if _selection_manager.any_units:
		_hide_panel()
		return

	var buildings := _selection_manager.get_selected_buildings_on_team()
	if buildings.size() != 1:
		_hide_panel()
		return

	var building := buildings[0]
	if building == null:
		_hide_panel()
		return

	if not (building is Barracks or building is Factory or building is CommandCenter):
		_hide_panel()
		return

	_current_building = building
	_set_current_manufacturing(building.manufacturing_component)
	_populate_build_row()
	_populate_queue_row()
	visible = true


func _set_current_manufacturing(component: ManufacturingComponent) -> void:
	if _current_manufacturing == component:
		return

	_disconnect_manufacturing_signals()
	_disconnect_resource_change_signals()
	
	_current_manufacturing = component
	if _current_manufacturing == null:
		return

	_current_manufacturing.build_queued.connect(_on_manufacturing_changed)
	_current_manufacturing.build_canceled.connect(_on_manufacturing_changed.unbind(1))
	_current_manufacturing.build_completed.connect(_on_manufacturing_changed.unbind(1))
	_current_manufacturing.build_started.connect(_on_manufacturing_changed)
	
	_connect_resource_change_signals()

func _connect_resource_change_signals() -> void:
	var match_team := Groups.get_parent_with_type(_current_manufacturing, MatchTeam) as MatchTeam
	if not match_team or not match_team.resources:
		return
		
	var scrap := match_team.resources.scrap
	scrap.count_changed.connect(_update_affordability.unbind(2))

	var personnel := match_team.resources.personnel
	personnel.count_changed.connect(_update_affordability.unbind(2))
	personnel.cap_changed.connect(_update_affordability.unbind(2))
	personnel.queued_count_changed.connect(_update_affordability.unbind(2))

func _disconnect_resource_change_signals() -> void:
	if _current_manufacturing == null:
		return
		
	var match_team := Groups.get_parent_with_type(_current_manufacturing, MatchTeam) as MatchTeam
	if not match_team or not match_team.resources:
		return
		
	var scrap := match_team.resources.scrap
	scrap.count_changed.disconnect(_update_affordability)

	var personnel := match_team.resources.personnel
	personnel.count_changed.disconnect(_update_affordability)
	personnel.cap_changed.disconnect(_update_affordability)
	personnel.queued_count_changed.disconnect(_update_affordability)
	
func _disconnect_manufacturing_signals() -> void:
	if _current_manufacturing == null:
		return

	_current_manufacturing.build_queued.disconnect(_on_manufacturing_changed)
	_current_manufacturing.build_canceled.disconnect(_on_manufacturing_changed.unbind(1))
	_current_manufacturing.build_completed.disconnect(_on_manufacturing_changed.unbind(1))
	_current_manufacturing.build_started.disconnect(_on_manufacturing_changed)


func _on_manufacturing_changed(_resource: ConstructionResource) -> void:
	_populate_build_row()
	_populate_queue_row()

func _update_affordability() -> void:
	_populate_build_row()
	
func _populate_build_row() -> void:
	var chips := _get_build_chips()
	var resources := _get_supported_resources()

	for i in chips.size():
		var chip := chips[i]
		var resource := resources[i] if i < resources.size() else null
		chip.set_show_count_badge(true)
		chip.set_show_personnel_cost(true)
		chip.set_show_personnel_cost(true)
		chip.set_show_inventory_count(false)
		chip.resource = resource
		chip.visible = resource != null
		if resource != null and _current_manufacturing != null:
			_apply_chip_resource_state(chip, resource)
			chip.set_can_afford(_current_manufacturing.can_build(resource.type))
		else:
			chip.set_missing_costs(false, false)


func _get_supported_resources() -> Array[ConstructionResource]:
	var resources: Array[ConstructionResource] = []
	if _current_manufacturing == null or _current_manufacturing.supported_types == null:
		return resources

	for default_resource in _current_manufacturing.supported_types.types:
		if default_resource == null:
			continue
		var resource := _current_manufacturing.get_build_metadata(default_resource.type)
		resources.push_back(resource if resource != null else default_resource)
	return resources


func _get_build_chips() -> Array[BuildingChip]:
	var chips: Array[BuildingChip] = []
	for child in build_row.get_children():
		var chip := child as BuildingChip
		if chip:
			chips.push_back(chip)
	return chips


func _on_chip_clicked(type: ConstructionResource.Type) -> void:
	if _current_manufacturing == null:
		return
	if not _current_manufacturing.can_build(type):
		return
	@warning_ignore("missing_await")
	_current_manufacturing.build(type)
	_populate_build_row()


func _on_queue_slot_clicked(slot_index: int) -> void:
	if _current_manufacturing == null:
		return
	if slot_index <= 0:
		return

	var queued := _current_manufacturing.currently_building
	if slot_index < 0 or slot_index >= queued.size():
		return

	# Access the actual queue element so we can cancel that exact slot.
	var queue_elements: Array = _current_manufacturing._build_queue
	if slot_index >= queue_elements.size():
		return

	_current_manufacturing.cancel_single_build(queue_elements[slot_index])


func _populate_queue_row() -> void:
	var slots := _get_queue_slots()
	if slots.is_empty():
		return

	var queued: Array[ConstructionResource] = []
	if _current_manufacturing != null:
		queued = _current_manufacturing.currently_building

	for i in slots.size():
		var slot := slots[i]
		var resource := queued[i] if i < queued.size() else null
		if resource == null:
			slot.clear()
			continue

		var active := i == 0

		var time_left := _current_manufacturing.build_timer.time_left
		if time_left <= 0:
			slot.set_resource(resource, 0.0, active)
		else:
			var wait_time := _current_manufacturing.build_timer.wait_time
			var progress:float = 1 - (time_left / wait_time)
			slot.set_resource(resource, progress, active)


func _get_queue_slots() -> Array[ProductionQueueSlot]:
	var slots: Array[ProductionQueueSlot] = []
	for child in queue_row.get_children():
		var slot := child as ProductionQueueSlot
		if slot:
			slots.push_back(slot)
	return slots


func _hide_panel() -> void:
	_current_building = null
	_set_current_manufacturing(null)
	for chip in _get_build_chips():
		chip.set_missing_costs(false, false)
		chip.resource = null
		chip.visible = false
	for slot in _get_queue_slots():
		slot.clear()
	visible = false


func _apply_chip_resource_state(chip: BuildingChip, resource: ConstructionResource) -> void:
	if _current_manufacturing == null or _current_manufacturing.get_parent() == null:
		chip.set_missing_costs(false, false)
		return

	var match_team := Groups.get_parent_with_type(_current_manufacturing, MatchTeam) as MatchTeam
	var team_resources := match_team.resources if match_team else null
	if team_resources == null:
		chip.set_missing_costs(false, false)
		return

	chip.set_missing_costs(
		team_resources.scrap.count < resource.cost,
		team_resources.personnel.remaining < resource.personnel
	)
