class_name HealthBar extends Node3D

@onready var sprite: Sprite3D = $Sprite

@export
var always_display:bool = false

@export
var health_stat:HealthStat

var _material: ShaderMaterial

func _ready() -> void:
	if not health_stat:
		push_error("%s: Missing health state set up" % name)
		return

	_material = _create_material_instance()
	if not _material:
		return

	_apply_health_fraction(health_stat.health_fraction)
	health_stat.health_changed.connect(_on_health_changed.unbind(2))

func _create_material_instance() -> ShaderMaterial:
	var material := sprite.material_override as ShaderMaterial
	if not material:
		push_error("%s: Sprite is missing a ShaderMaterial override" % name)
		return null

	material = material.duplicate()
	sprite.material_override = material
	return material

func _apply_health_fraction(fraction:float) -> void:
	_update_visible(fraction)
	_material.set_shader_parameter(&"health_fraction", fraction)

func _update_visible(fraction:float) -> void:
	if always_display:
		return
		
	if fraction < 1.0:
		show()
	else:
		hide()
			
func _on_health_changed() -> void:
	var fraction:float = health_stat.health_fraction
	_apply_health_fraction(fraction)
