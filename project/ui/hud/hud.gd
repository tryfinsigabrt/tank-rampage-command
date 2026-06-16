class_name HUD extends MarginContainer

static var BUILDING_BORDER_COLOR := Color(0.59607846, 0.4117647, 0.06666667, 1)
static var DEFAULT_BORDER_COLOR := Color(0.08235294, 0.23921569, 0.2784314, 1)
static var BORDER_WIDTH := 4
static var COMMAND_BORDER_COLOR := Color(0.14509803, 0.40784314, 0.47058823)

@onready var player_message_panel: PanelContainer = %PlayerMessagePanel

func _ready() -> void:
	SignalBus.on_player_message_requested.connect(_on_player_message_requested)
	SignalBus.on_player_message_cleared.connect(_on_player_message_cleared)

func _on_player_message_requested(message_text: String) -> void:
	if player_message_panel and player_message_panel.has_method("show_message"):
		player_message_panel.show_message(message_text)

func _on_player_message_cleared() -> void:
	if player_message_panel and player_message_panel.has_method("clear_message"):
		player_message_panel.clear_message()
