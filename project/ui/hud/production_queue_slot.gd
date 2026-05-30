class_name ProductionQueueSlot extends PanelContainer

@onready var icon: TextureRect = %QueueIcon
@onready var empty_label: Label = %EmptyLabel

var _progress_material: ShaderMaterial

func _ready() -> void:
	var material = (icon.material as ShaderMaterial).duplicate()
	icon.material = material
	_progress_material = material
	_show_empty()

func set_resource(resource: ConstructionResource, progress: float = 0.0, active: bool = false) -> void:
	if resource == null:
		_show_empty()
		return

	visible = true
	empty_label.visible = false
	icon.visible = true
	icon.texture = resource.icon
	var clamped_progress := clampf(progress, 0.0, 1.0)
	if _progress_material:
		_progress_material.set_shader_parameter(&"progress", clamped_progress if active else 0)

func clear() -> void:
	_show_empty()

func _show_empty() -> void:
	visible = true
	icon.visible = false
	empty_label.visible = true
	if _progress_material:
		_progress_material.set_shader_parameter(&"progress", 0.0)
