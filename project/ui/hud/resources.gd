extends HBoxContainer

const COMPACT_MAX_WIDTH: int = 1100
const LARGE_MIN_WIDTH: int = 2200

enum SizeTier {
	COMPACT,
	STANDARD,
	LARGE,
}

@onready var resource_row: HBoxContainer = %ResourceRow
@onready var personnel_chip: HBoxContainer = %PersonnelChip
@onready var scrap_chip: HBoxContainer = %ScrapChip
@onready var resource_panel_padding: MarginContainer = %ResourcePanelPadding
@onready var personnel_chip_padding: MarginContainer = %PersonnelChipPadding
@onready var scrap_chip_padding: MarginContainer = %ScrapChipPadding
@onready var personnel_badge: PanelContainer = %PersonnelBadge
@onready var scrap_badge: PanelContainer = %ScrapBadge
@onready var personnel_value: Label = %PersonnelValue
@onready var personnel_queued_value: Label = %PersonnelQueuedValue
@onready var scrap_value: Label = %ScrapValue

var _match_team:MatchTeam

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_size_tier)
	_apply_size_tier()

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
	
func _connect_signals() -> void:
	var team_resources := _match_team.resources
	
	# Set initial values and then bind signals
	var pers := team_resources.personnel
	var scrap := team_resources.scrap
	
	_set_personnel_value(pers)
	_set_scrap_value(scrap)
	
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

func _set_scrap_value(scrap:ScrapResource) -> void:
	scrap_value.text = str(scrap.count)

func _set_personnel_value(pers:PersonnelResource) -> void:
	personnel_value.text = "%d/%d" % [pers.count, pers.cap]
	personnel_queued_value.visible = pers.queued_count > 0
	if pers.queued_count > 0:
		personnel_queued_value.text = "+%d" % pers.queued_count

func _apply_size_tier() -> void:
	var width := get_viewport_rect().size.x
	var tier := _get_size_tier(width)

	match tier:
		SizeTier.COMPACT:
			resource_row.add_theme_constant_override("separation", 10)
			_set_panel_padding(12, 7)
			_set_chip_inner_padding(0, 0)
			_set_chip_widths(144, 115)
			_set_font_sizes(19, 16)
		SizeTier.STANDARD:
			resource_row.add_theme_constant_override("separation", 14)
			_set_panel_padding(17, 10)
			_set_chip_inner_padding(0, 0)
			_set_chip_widths(178, 144)
			_set_font_sizes(26, 19)
		SizeTier.LARGE:
			resource_row.add_theme_constant_override("separation", 19)
			_set_panel_padding(22, 12)
			_set_chip_inner_padding(0, 0)
			_set_chip_widths(211, 173)
			_set_font_sizes(34, 24)

func _get_size_tier(width: float) -> SizeTier:
	if width <= COMPACT_MAX_WIDTH:
		return SizeTier.COMPACT
	if width >= LARGE_MIN_WIDTH:
		return SizeTier.LARGE
	return SizeTier.STANDARD

func _set_panel_padding(horizontal: int, vertical: int) -> void:
	resource_panel_padding.add_theme_constant_override("margin_left", horizontal)
	resource_panel_padding.add_theme_constant_override("margin_right", horizontal)
	resource_panel_padding.add_theme_constant_override("margin_top", vertical)
	resource_panel_padding.add_theme_constant_override("margin_bottom", vertical)

func _set_chip_inner_padding(horizontal: int, vertical: int) -> void:
	for container in [personnel_chip_padding, scrap_chip_padding]:
		container.add_theme_constant_override("margin_left", horizontal)
		container.add_theme_constant_override("margin_right", horizontal)
		container.add_theme_constant_override("margin_top", vertical)
		container.add_theme_constant_override("margin_bottom", vertical)

func _set_chip_widths(personnel_width: int, scrap_width: int) -> void:
	personnel_chip.custom_minimum_size.x = personnel_width
	scrap_chip.custom_minimum_size.x = scrap_width

func _set_font_sizes(value_size: int, queued_size: int) -> void:
	personnel_value.add_theme_font_size_override("font_size", value_size)
	personnel_queued_value.add_theme_font_size_override("font_size", queued_size)
	scrap_value.add_theme_font_size_override("font_size", value_size)
