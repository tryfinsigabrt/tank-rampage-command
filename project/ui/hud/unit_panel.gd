extends PanelContainer

var _selection_manager: SelectionManager
var _watched_containers: Array[UnitContainerComponent] = []

@onready var unit_row: HFlowContainer = %UnitRow
@onready var occupants_info: VBoxContainer = %OccupantsInfo
@onready var occupants_row: HFlowContainer = %OccupantsRow

const UNIT_CHIP_SCENE: PackedScene = preload("res://ui/hud/unit_chip.tscn")

func _ready() -> void:
	set_process(false)
	visible = false
	
	_connect_selection_sources()
	_refresh_visibility()

func _exit_tree() -> void:
	if SignalBus.on_unit_selected.is_connected(_on_selection_changed):
		SignalBus.on_unit_selected.disconnect(_on_selection_changed)
	if SignalBus.on_unit_deselected.is_connected(_on_selection_changed):
		SignalBus.on_unit_deselected.disconnect(_on_selection_changed)
	if SignalBus.on_unit_killed.is_connected(_on_unit_killed):
		SignalBus.on_unit_killed.disconnect(_on_unit_killed)
	if SignalBus.on_building_selected.is_connected(_on_selection_changed):
		SignalBus.on_building_selected.disconnect(_on_selection_changed)
	if SignalBus.on_building_deselected.is_connected(_on_selection_changed):
		SignalBus.on_building_deselected.disconnect(_on_selection_changed)
	if SignalBus.on_structure_selected.is_connected(_on_selection_changed):
		SignalBus.on_structure_selected.disconnect(_on_selection_changed)
	if SignalBus.on_structure_deselected.is_connected(_on_selection_changed):
		SignalBus.on_structure_deselected.disconnect(_on_selection_changed)
	_disconnect_container_signals()

func _connect_selection_sources() -> void:
	var player := get_tree().get_first_node_in_group(Groups.Player) as Player
	if player:
		_selection_manager = player.player_unit_actions.selection_manager

	SignalBus.on_unit_selected.connect(_on_selection_changed)
	SignalBus.on_unit_deselected.connect(_on_selection_changed)
	SignalBus.on_unit_killed.connect(_on_unit_killed)
	SignalBus.on_building_selected.connect(_on_selection_changed)
	SignalBus.on_building_deselected.connect(_on_selection_changed)
	SignalBus.on_structure_selected.connect(_on_selection_changed)
	SignalBus.on_structure_deselected.connect(_on_selection_changed)

func _on_selection_changed(asset: Node3D) -> void:
	if _should_schedule_refresh(asset):
		_schedule_refresh()

func _on_unit_killed(unit: Unit, _damage: DamageParameters) -> void:
	if _should_schedule_refresh(unit):
		_schedule_refresh()

func _should_schedule_refresh(asset: Node3D) -> bool:
	# Only update when own team is affected
	var team_comp := TeamComponent.get_component(asset, false)
	return _selection_manager and team_comp and team_comp.is_on_team(_selection_manager.team)

func _schedule_refresh() -> void:
	set_process(true)
		
func _process(_delta: float) -> void:
	# Using _process to dedup and batch the last refresh command 
	_refresh_visibility()
	set_process(false)
	
func _refresh_visibility() -> void:
	if _selection_manager == null:
		visible = false
		_clear_unit_chips()
		_clear_occupant_chips()
		return

	var selected_units := _get_live_selected_units()
	var selected_containers := _get_selected_containers()
	var occupants := _get_selected_occupants()
	visible = not selected_units.is_empty() or not selected_containers.is_empty()
	_update_watched_containers(selected_containers)
	if visible:
		_populate_units(selected_units)
		_populate_occupants(occupants, _get_total_container_capacity(selected_containers))
	else:
		_clear_unit_chips()
		_clear_occupant_chips()

func _populate_units(units: Array[Unit]) -> void:
	_clear_unit_chips()

	for unit in units:
		var chip := UNIT_CHIP_SCENE.instantiate() as UnitChip
		if chip == null:
			continue
		chip.unit = unit
		unit_row.add_child(chip)

func _clear_unit_chips() -> void:
	for child in unit_row.get_children():
		child.queue_free()

func _populate_occupants(units: Array[Unit], capacity: int) -> void:
	_clear_occupant_chips()
	occupants_info.visible = capacity > 0
	for unit in units:
		var chip := UNIT_CHIP_SCENE.instantiate() as UnitChip
		if chip == null:
			continue
		chip.unit = unit
		occupants_row.add_child(chip)

	for i in maxi(capacity - units.size(), 0):
		var chip := UNIT_CHIP_SCENE.instantiate() as UnitChip
		if chip == null:
			continue
		chip.set_empty()
		occupants_row.add_child(chip)

func _clear_occupant_chips() -> void:
	occupants_info.visible = false
	for child in occupants_row.get_children():
		child.queue_free()

func _get_live_selected_units() -> Array[Unit]:
	var live_units: Array[Unit] = []
	if _selection_manager == null:
		return live_units

	for unit in _selection_manager.get_selected_units_on_team():
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.is_dead:
			continue
		live_units.push_back(unit)

	live_units.sort_custom(func(a: Unit, b: Unit) -> bool:
		var a_priority := _unit_class_priority(a.unit_class)
		var b_priority := _unit_class_priority(b.unit_class)
		if a_priority != b_priority:
			return a_priority < b_priority
		return a.get_instance_id() < b.get_instance_id()
	)

	return live_units

func _get_selected_occupants() -> Array[Unit]:
	var occupants: Array[Unit] = []
	if _selection_manager == null:
		return occupants

	var seen: Dictionary[int, bool] = {}
	for container in _get_selected_containers():
		for unit in container.units:
			if unit == null or not is_instance_valid(unit) or unit.is_dead:
				continue
			var id := unit.get_instance_id()
			if id in seen:
				continue
			seen[id] = true
			occupants.push_back(unit)

	occupants.sort_custom(func(a: Unit, b: Unit) -> bool:
		var a_priority := _unit_class_priority(a.unit_class)
		var b_priority := _unit_class_priority(b.unit_class)
		if a_priority != b_priority:
			return a_priority < b_priority
		return a.get_instance_id() < b.get_instance_id()
	)
	return occupants


func _update_watched_containers(current: Array[UnitContainerComponent]) -> void:
	for container in _watched_containers:
		if container and container.on_unit_added.is_connected(_on_container_units_changed):
			container.on_unit_added.disconnect(_on_container_units_changed)
		if container and container.on_unit_removed.is_connected(_on_container_units_changed):
			container.on_unit_removed.disconnect(_on_container_units_changed)

	_watched_containers = current
	for container in _watched_containers:
		if not container.on_unit_added.is_connected(_on_container_units_changed):
			container.on_unit_added.connect(_on_container_units_changed)
		if not container.on_unit_removed.is_connected(_on_container_units_changed):
			container.on_unit_removed.connect(_on_container_units_changed)

func _get_selected_containers() -> Array[UnitContainerComponent]:
	var containers: Array[UnitContainerComponent] = []
	if _selection_manager == null:
		return containers

	for asset in _selection_manager.get_selected_units_on_team():
		var container := UnitContainerComponent.get_component(asset, false)
		if container and not container in containers:
			containers.push_back(container)

	for asset in _selection_manager.get_selected_structures_on_team():
		var container := UnitContainerComponent.get_component(asset, false)
		if container and not container in containers:
			containers.push_back(container)

	return containers

func _get_total_container_capacity(containers: Array[UnitContainerComponent]) -> int:
	var capacity := 0
	for container in containers:
		capacity += container.capacity
	return capacity

func _disconnect_container_signals() -> void:
	for container in _watched_containers:
		if container and container.on_unit_added.is_connected(_on_container_units_changed):
			container.on_unit_added.disconnect(_on_container_units_changed)
		if container and container.on_unit_removed.is_connected(_on_container_units_changed):
			container.on_unit_removed.disconnect(_on_container_units_changed)
	_watched_containers.clear()

func _on_container_units_changed(_unit: Unit) -> void:
	_schedule_refresh()

func _unit_class_priority(unit_class: Unit.UnitClass) -> int:
	match unit_class:
		Unit.UnitClass.Artillery:
			return 0
		Unit.UnitClass.Tank:
			return 1
		Unit.UnitClass.Soldier:
			return 2
		_:
			return 99
