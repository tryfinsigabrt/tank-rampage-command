class_name CommandChip extends PanelContainer

signal clicked(command_name: String)

const COMMAND_ICONS := {
	"Move": preload("res://ui/hud/icons/move.png"),
	"Attack": preload("res://ui/hud/icons/attack.png"),
	"Move And Attack": preload("res://ui/hud/icons/move_and_attack.png"),
	"Stop": preload("res://ui/hud/icons/stop.png"),
	"Hold": preload("res://ui/hud/icons/hold.png"),
	"Set Spawn Point": preload("res://ui/hud/icons/set_spawn.png"),
	"Clear Spawn Point": preload("res://ui/hud/icons/clear_spawn.png"),
}

@export var command_name: String:
	set(value):
		command_name = value
		if is_node_ready():
			_apply_command_name()

@onready var command_icon: TextureRect = %CommandIcon

func _ready() -> void:
	_apply_command_name()

func _apply_command_name() -> void:
	tooltip_text = command_name
	command_icon.texture = COMMAND_ICONS.get(command_name)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(command_name)
		accept_event()
