class_name UnitVisualIndicator
extends Sprite3D

@export var root_unit: Unit

@export_range(0.0, 0.5) var fade_begin: float = 0.1
@export_range(0.0, 0.5) var fade_end: float = 0.4

@export_range(0.0, 1.0) var min_opacity: float = 0.2
@export_range(0.0, 1.0) var max_opacity: float = 0.9
@export_range(0.0, 1.0) var selected_transparency: float = 0.9

var is_selected: bool = false


func get_distance_ratio_to_viewport_center() -> float:
	var viewport := get_viewport()
	var position_in_viewport := viewport.get_camera_3d().unproject_position(global_transform.origin)
	var viewport_size := viewport.get_visible_rect().size
	var ratio_to_center := (position_in_viewport / viewport_size).distance_to(Vector2(0.5, 0.5))
	return ratio_to_center


func _process(_delta: float) -> void:
	if is_selected:
		transparency = selected_transparency
	else:
		var ratio_to_center := get_distance_ratio_to_viewport_center()
		var fade_ratio := ratio_to_center * 2
		var target_transparency := clampf(lerpf(min_opacity, max_opacity, fade_ratio), min_opacity, max_opacity)
		transparency = target_transparency


func _on_unit_selected(unit: Unit) -> void:
	if is_instance_valid(root_unit) and unit == root_unit:
		is_selected = true

func _on_unit_deselected(unit: Unit) -> void:
	if is_instance_valid(root_unit) and unit == root_unit:
		is_selected = false

func _ready() -> void:
	SignalBus.on_unit_selected.connect(_on_unit_selected)
	SignalBus.on_unit_deselected.connect(_on_unit_deselected)
