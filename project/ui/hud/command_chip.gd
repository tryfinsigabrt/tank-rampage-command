class_name CommandChip extends PanelContainer

signal clicked(command_name: String)



const COMMAND_ICONS := {
	"Move": preload("res://ui/hud/icons/move_64.png"),
	"Attack": preload("res://ui/hud/icons/attack_64.png"),
	"Move And Attack": preload("res://ui/hud/icons/move_and_attack_64.png"),
	"Stop": preload("res://ui/hud/icons/stop_64.png"),
	"Hold": preload("res://ui/hud/icons/hold_64.png"),
	"Exit": preload("res://ui/hud/icons/exit_64.png"),
	"Set Spawn Point": preload("res://ui/hud/icons/set_spawn_64.png"),
	"Clear Spawn Point": preload("res://ui/hud/icons/clear_spawn_64.png"),
}

@export var command_name: String:
	set(value):
		command_name = value
		if is_node_ready():
			_apply_command_name()

@onready var command_icon: TextureRect = %CommandIcon

var _hovered: bool = false

func _ready() -> void:
	_apply_command_name()
	_update_border_style()

func _apply_command_name() -> void:
	tooltip_text = command_name
	command_icon.texture = COMMAND_ICONS.get(command_name)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(command_name)
		accept_event()

func _on_mouse_entered() -> void:
	_hovered = true
	_update_border_style()

func _on_mouse_exited() -> void:
	_hovered = false
	_update_border_style()

func _update_border_style() -> void:
	var stylebox := get_theme_stylebox("panel") as StyleBoxFlat
	if stylebox == null:
		return

	stylebox = stylebox.duplicate() as StyleBoxFlat
	if stylebox == null:
		return

	stylebox.border_width_left = HUD.BORDER_WIDTH
	stylebox.border_width_top = HUD.BORDER_WIDTH
	stylebox.border_width_right = HUD.BORDER_WIDTH
	stylebox.border_width_bottom = HUD.BORDER_WIDTH
	stylebox.border_color = HUD.COMMAND_BORDER_COLOR if _hovered else HUD.DEFAULT_BORDER_COLOR
	add_theme_stylebox_override("panel", stylebox)
