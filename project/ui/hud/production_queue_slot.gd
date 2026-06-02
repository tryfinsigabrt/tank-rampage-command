class_name ProductionQueueSlot extends PanelContainer

signal clicked(slot_index: int)

@onready var icon: TextureRect = %QueueIcon
@onready var empty_label: Label = %EmptyLabel

var _progress_material: ShaderMaterial
var _hovered: bool = false
var slot_index: int = -1
var _has_resource: bool = false

func _ready() -> void:
	var material = (icon.material as ShaderMaterial).duplicate()
	icon.material = material
	_progress_material = material
	_show_empty()
	_update_border_style()

func set_resource(resource: ConstructionResource, progress: float = 0.0, active: bool = false) -> void:
	if resource == null:
		_show_empty()
		return

	_has_resource = true
	visible = true
	empty_label.visible = false
	icon.visible = true
	icon.texture = resource.icon
	var clamped_progress := clampf(progress, 0.0, 1.0)
	if _progress_material:
		_progress_material.set_shader_parameter(&"progress", clamped_progress if active else 0)

func clear() -> void:
	_show_empty()

func _gui_input(event: InputEvent) -> void:
	if slot_index == 0 or not _has_resource:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(slot_index)
		accept_event()

func _show_empty() -> void:
	_has_resource = false
	visible = true
	icon.visible = false
	empty_label.visible = true
	_hovered = false
	if _progress_material:
		_progress_material.set_shader_parameter(&"progress", 0.0)
	_update_border_style()

func _on_mouse_entered() -> void:
	if slot_index == 0 or not _has_resource:
		return
	_hovered = true
	_update_border_style()

func _on_mouse_exited() -> void:
	if slot_index == 0:
		_hovered = false
		_update_border_style()
		return
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
	stylebox.border_color = HUD.BUILDING_BORDER_COLOR if _hovered else HUD.DEFAULT_BORDER_COLOR
	add_theme_stylebox_override("panel", stylebox)
