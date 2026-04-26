class_name BuildProgressBar extends Node3D

@onready var sprite: Sprite3D = $Sprite

func _ready() -> void:
	set_progress(0.0)
	
func set_progress(fraction:float) -> void:
	sprite.set_instance_shader_parameter(&"health_fraction", fraction)
