class_name HealthBar extends Node3D

@onready var sprite: Sprite3D = $Sprite

@export
var always_display:bool = false

@export
var health_stat:HealthStat

func _ready() -> void:
	if not health_stat:
		push_error("%s: Missing health state set up" % name)
		return
		
	_update_visible(health_stat.health_fraction)
	health_stat.health_changed.connect(_on_health_changed.unbind(2))

func _update_visible(fraction:float) -> void:
	if always_display:
		return
		
	if fraction < 1.0:
		show()
	else:
		hide()
			
func _on_health_changed() -> void:
	var fraction:float = health_stat.health_fraction
	_update_visible(fraction)
		
	sprite.set_instance_shader_parameter(&"health_fraction", fraction)
