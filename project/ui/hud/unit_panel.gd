extends PanelContainer

var _selection_manager: SelectionManager

@onready var unit_row: HFlowContainer = %UnitRow

const UNIT_CHIP_SCENE: PackedScene = preload("res://ui/hud/unit_chip.tscn")

func _ready() -> void:
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

func _connect_selection_sources() -> void:
	var player := get_tree().get_first_node_in_group(Groups.Player) as Player
	if player:
		_selection_manager = player.player_unit_actions.selection_manager

	SignalBus.on_unit_selected.connect(_on_selection_changed)
	SignalBus.on_unit_deselected.connect(_on_selection_changed)
	SignalBus.on_unit_killed.connect(_on_unit_killed)
	SignalBus.on_building_selected.connect(_on_selection_changed)
	SignalBus.on_building_deselected.connect(_on_selection_changed)

func _on_selection_changed(_asset: Node3D) -> void:
	_refresh_visibility()

func _on_unit_killed(_unit: Unit, _damage: DamageParameters) -> void:
	_refresh_visibility()

func _refresh_visibility() -> void:
	if _selection_manager == null:
		visible = false
		_clear_unit_chips()
		return

	var selected_units := _get_live_selected_units()
	visible = not selected_units.is_empty()
	if visible:
		_populate_units(selected_units)
	else:
		_clear_unit_chips()

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
