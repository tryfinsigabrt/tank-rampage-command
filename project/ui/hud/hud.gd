class_name HUD extends MarginContainer

signal ui_element_entered(code: StringName, extra: String)
signal ui_element_exited(code: StringName)

static var BUILDING_BORDER_COLOR := Color(0.59607846, 0.4117647, 0.06666667, 1)
static var DEFAULT_BORDER_COLOR := Color(0.08235294, 0.23921569, 0.2784314, 1)
static var BORDER_WIDTH := 4
static var COMMAND_BORDER_COLOR := Color(0.14509803, 0.40784314, 0.47058823)

@onready var player_message_panel: PanelContainer = %PlayerMessagePanel
@onready var tooltip_layer: TooltipLayer = %TooltipLayer
@onready var fps_label: Label = %FpsLabel

var _fps_update_elapsed := 0.0

func _ready() -> void:
	SignalBus.on_player_message_requested.connect(_on_player_message_requested)
	SignalBus.on_player_message_cleared.connect(_on_player_message_cleared)
	PlayerSettings.show_fps_changed.connect(_on_show_fps_changed)
	set_process(PlayerSettings.get_show_fps())
	_on_show_fps_changed(PlayerSettings.get_show_fps())


func _process(delta: float) -> void:
	_fps_update_elapsed += delta
	if _fps_update_elapsed < 1.0:
		return

	_fps_update_elapsed = 0.0
	_update_fps()


func _on_player_message_requested(message_text: String) -> void:
	if player_message_panel and player_message_panel.has_method("show_message"):
		player_message_panel.show_message(message_text)


func _on_player_message_cleared() -> void:
	if player_message_panel and player_message_panel.has_method("clear_message"):
		player_message_panel.clear_message()


func set_tooltip_data(code: StringName, tooltip_data: Dictionary) -> void:
	if tooltip_layer:
		tooltip_layer.set_tooltip_data(code, tooltip_data)


func _on_show_fps_changed(value: bool) -> void:
	fps_label.visible = value
	_update_fps()
	# Only FPS counter needs process in HUD right now, so we just enable it here
	# for the entire HUD script, if more things added in the future, change it
	set_process(value)


func _update_fps() -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
