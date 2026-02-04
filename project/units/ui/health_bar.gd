class_name HealthBar extends Node3D

@onready var sprite: Sprite3D = $Sprite

@export
var health_stat:HealthStat

func _ready() -> void:
	if not health_stat:
		push_error("%s: Missing health state set up" % name)
		return
	health_stat.health_changed.connect(_on_health_changed.unbind(2))
	
func _on_health_changed() -> void:
	sprite.set_instance_shader_parameter(&"health_fraction", health_stat.health_fraction)
