extends PanelContainer

const COMMAND_CHIP_SCENE: PackedScene = preload("res://ui/hud/command_chip.tscn")

const UNIT_COMMANDS := [
	"Move",
	"Attack",
	"Move And Attack",
	"Stop",
	"Hold",
]

const BUILDING_COMMANDS := [
	"Set Spawn Point",
	"Clear Spawn Point",
]

@onready var command_row: GridContainer = %CommandRow

var _selection_manager: SelectionManager
var _player_actions: PlayerTeamActions
var _rally_point_manager: RallyPointManager
var _unit_container_actions: UnitContainerActions

func _ready() -> void:
	visible = false
	_connect_selection_sources()
	_refresh_commands()

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

func _connect_selection_sources() -> void:
	var player := get_tree().get_first_node_in_group(Groups.Player) as Player
	if player:
		_player_actions = player.player_unit_actions
		_selection_manager = player.player_unit_actions.selection_manager
		_rally_point_manager = _player_actions.get_node_or_null("SelectionManager/RallyPointManager") as RallyPointManager
		_unit_container_actions = _player_actions.get_node_or_null("Actions/UnitContainerActions") as UnitContainerActions

	SignalBus.on_unit_selected.connect(_on_selection_changed)
	SignalBus.on_unit_deselected.connect(_on_selection_changed)
	SignalBus.on_unit_killed.connect(_on_unit_killed)
	SignalBus.on_building_selected.connect(_on_selection_changed)
	SignalBus.on_building_deselected.connect(_on_selection_changed)
	SignalBus.on_structure_selected.connect(_on_selection_changed)
	SignalBus.on_structure_deselected.connect(_on_selection_changed)

func _on_selection_changed(_asset: Node3D) -> void:
	_refresh_commands()

func _on_unit_killed(_unit: Unit, _damage: DamageParameters) -> void:
	_refresh_commands()

func _refresh_commands() -> void:
	_clear_command_chips()
	if _selection_manager == null:
		visible = false
		return

	if _has_live_selected_units():
		var commands := UNIT_COMMANDS.duplicate()
		if _has_selected_container_assets():
			commands.push_back("Exit")
		_populate_commands(commands)
		visible = true
		return

	var buildings := _selection_manager.get_selected_buildings_on_team()
	if buildings.size() == 1 and (buildings[0] is Barracks or buildings[0] is Factory):
		_populate_commands(BUILDING_COMMANDS)
		visible = true
		return

	if _has_selected_container_assets():
		_populate_commands(["Exit"])
		visible = true
		return

	visible = false

func _has_live_selected_units() -> bool:
	if _selection_manager == null:
		return false

	for unit in _selection_manager.get_selected_units_on_team():
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.is_dead:
			continue
		return true

	return false

func _has_selected_container_assets() -> bool:
	if _selection_manager == null:
		return false

	for unit in _selection_manager.get_selected_units_on_team():
		if UnitContainerComponent.get_component(unit, false):
			return true

	for structure in _selection_manager.get_selected_structures_on_team():
		if UnitContainerComponent.get_component(structure, false):
			return true

	return false

func _populate_commands(commands: Array) -> void:
	for command_name in commands:
		var chip := COMMAND_CHIP_SCENE.instantiate() as CommandChip
		if chip == null:
			continue
		chip.command_name = command_name
		chip.clicked.connect(_on_command_clicked)
		command_row.add_child(chip)

func _clear_command_chips() -> void:
	for child in command_row.get_children():
		child.queue_free()

func _on_command_clicked(command_name: String) -> void:
	match command_name:
		"Move":
			if _player_actions:
				_player_actions.begin_move_mode()
		"Attack":
			if _player_actions:
				_player_actions.begin_attack_mode()
		"Move And Attack":
			if _player_actions:
				_player_actions.begin_move_and_attack_mode()
		"Stop":
			if _player_actions:
				_player_actions.issue_stop()
		"Hold":
			if _player_actions:
				_player_actions.issue_hold()
		"Exit":
			if _unit_container_actions:
				_unit_container_actions.unload_all_units()
		"Set Spawn Point":
			if _rally_point_manager:
				_rally_point_manager.begin_set_rally_point()
		"Clear Spawn Point":
			if _rally_point_manager:
				_rally_point_manager.clear_selected_rally_points()
