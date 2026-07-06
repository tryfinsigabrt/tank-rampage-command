extends HBoxContainer

@onready var resource_row: HBoxContainer = %ResourceRow
@onready var personnel_chip: HBoxContainer = %PersonnelChip
@onready var scrap_chip: HBoxContainer = %ScrapChip
@onready var scrap_chip_padding: MarginContainer = %ScrapChipPadding
@onready var personnel_value: Label = %PersonnelValue
@onready var personnel_queued_value: Label = %PersonnelQueuedValue
@onready var scrap_value: Label = %ScrapValue
@onready var scrap_income_value: Label = %ScrapIncomeValue

var _match_team:MatchTeam
var _hud: HUD

func _ready() -> void:
	_hud = Groups.get_parent_with_type(self, HUD) as HUD
	personnel_chip.mouse_entered.connect(_on_personnel_mouse_entered)
	personnel_chip.mouse_exited.connect(_on_personnel_mouse_exited)
	scrap_chip.mouse_entered.connect(_on_scrap_mouse_entered)
	scrap_chip.mouse_exited.connect(_on_scrap_mouse_exited)
	var player:Player = get_tree().get_first_node_in_group(Groups.Player) as Player
	if not player:
		push_warning("%s: Could not find player - resources will display 0's" % name)
		_default_values()
		return
	_match_team = player.player_team
	if not _match_team:
		push_warning("%s: MatchTeam not assigned to player node %s - resources will display 0's" % [name, player.name])
		_default_values()
		return
	_connect_signals.call_deferred()


func _process(_delta: float) -> void:
	if _match_team == null:
		return
	_set_scrap_income_value()


func _connect_signals() -> void:
	var team_resources := _match_team.resources
	
	# Set initial values and then bind signals
	var pers := team_resources.personnel
	var scrap := team_resources.scrap
	
	_set_personnel_value(pers)
	_set_scrap_value(scrap)
	_set_scrap_income_value()
	_update_resource_tooltips()
	
	var on_pers_changed:Callable = _set_personnel_value.bind(pers).unbind(2)
	pers.count_changed.connect(on_pers_changed)
	pers.cap_changed.connect(on_pers_changed)
	pers.queued_count_changed.connect(on_pers_changed)

	var on_scrap_changed:Callable = _set_scrap_value.bind(scrap).unbind(2)
	scrap.count_changed.connect(on_scrap_changed)
	scrap.cap_changed.connect(on_scrap_changed)


func _default_values() -> void:
	personnel_value.text = "0/0"
	personnel_queued_value.visible = false
	scrap_value.text = "0"
	scrap_income_value.visible = false
	_update_resource_tooltips()


func _set_scrap_value(scrap:ScrapResource) -> void:
	scrap_value.text = str(scrap.count)
	_update_resource_tooltips()


func _set_scrap_income_value() -> void:
	if _match_team == null:
		scrap_income_value.visible = false
		return

	var rounded_rate := roundi(_match_team.scrap_per_minute)
	scrap_income_value.visible = rounded_rate > 0
	if rounded_rate > 0:
		scrap_income_value.text = "+%d" % rounded_rate
	_update_resource_tooltips()


func _set_personnel_value(pers:PersonnelResource) -> void:
	personnel_value.text = "%d/%d" % [pers.count, pers.cap]
	personnel_queued_value.visible = pers.queued_count > 0
	if pers.queued_count > 0:
		personnel_queued_value.text = "+%d" % pers.queued_count
	_update_resource_tooltips()


func _update_resource_tooltips() -> void:
	if _hud == null or _match_team == null or _match_team.resources == null:
		return

	var personnel := _match_team.resources.personnel
	var personnel_details = "Current Personnel: %d\nIncoming Personnel: %d\nPersonnel Capacity: %d" % [
		personnel.count,
		personnel.queued_count,
		personnel.cap,
	]

	var scrap := _match_team.resources.scrap
	var scrap_details = "Current Scrap: %d\nCurrent Income: %d per minute" % [
		scrap.count,
		roundi(_match_team.scrap_per_minute),
	]

	_hud.set_tooltip_data(&"resource_personnel", {
		"title": "Personnel",
		"subtitle": personnel_details,
		"content": "To increase Personnel Capacity capture more Control Points.",
	})
	_hud.set_tooltip_data(&"resource_scrap", {
		"title": "Scrap",
		"subtitle": scrap_details,
		"content": "To increase Scrap income build Command Centers over Scrap Fields",
	})


func _on_personnel_mouse_entered() -> void:
	if _hud:
		_hud.ui_element_entered.emit(&"resource_personnel", "")


func _on_personnel_mouse_exited() -> void:
	if _hud:
		_hud.ui_element_exited.emit(&"resource_personnel")


func _on_scrap_mouse_entered() -> void:
	if _hud:
		_hud.ui_element_entered.emit(&"resource_scrap", "")


func _on_scrap_mouse_exited() -> void:
	if _hud:
		_hud.ui_element_exited.emit(&"resource_scrap")
