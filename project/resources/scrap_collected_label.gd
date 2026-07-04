class_name ScrapCollectedLabel extends Label3D

@export
var lifetime:float = -1.0

@export
var max_scale:float = 3.0

@export
var vertical_speed:float = 20.0

func _ready() -> void:
	if lifetime <= 0:
		return
		
	queue_free_after_lifetime()
	# TODO: Tween the scale and translate upward at speed over lifetime
	# Also fade the modulate alpha to 0.0
	
func queue_free_after_lifetime() -> void:
	var timer:Timer = Timer.new()
	timer.name = "LifetimeTimer"
	timer.autostart = true
	timer.one_shot = true
	timer.wait_time = lifetime
	timer.timeout.connect(queue_free)
	add_child(timer)
