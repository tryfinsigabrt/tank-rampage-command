class_name BuildProgressBar extends Node3D

@onready var sprite: Sprite3D = $Sprite

var _material: ShaderMaterial

func _ready() -> void:
	_material = _create_material_instance()
	if not _material:
		return

	set_progress(0.0)

func _create_material_instance() -> ShaderMaterial:
	var material := sprite.material_override as ShaderMaterial
	if not material:
		push_error("%s: Sprite is missing a ShaderMaterial override" % name)
		return null

	material = material.duplicate()
	sprite.material_override = material
	return material
	
func set_progress(fraction:float) -> void:
	if not _material:
		return

	_material.set_shader_parameter(&"health_fraction", fraction)
