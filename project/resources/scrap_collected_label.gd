class_name ScrapCollectedLabel extends Label3D

@export
var lifetime:float = 5

@export
var max_scale:float = 1.5

@export
var vertical_speed:float = 5.0

@export
var scrap_amount:int = 5

func _ready() -> void:
	text = "+%d" % scrap_amount
	
	if lifetime <= 0:
		return
		
	queue_free_after_lifetime()
	play_collection_tween()
	
func play_collection_tween() -> void:
	var end_scale := scale * max_scale
	var end_position := position + Vector3.UP * vertical_speed * lifetime
	
	var tween := create_tween() \
		.set_trans(Tween.TRANS_QUART) \
		.set_ease(Tween.EASE_OUT)
	
	tween.set_parallel(true)
	tween.tween_property(self, "scale", end_scale, lifetime)
	tween.tween_property(self, "position", end_position, lifetime)
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	tween.tween_property(self, "outline_modulate:a", 0.0, lifetime)

func queue_free_after_lifetime() -> void:
	var timer:Timer = Timer.new()
	timer.name = "LifetimeTimer"
	timer.autostart = true
	timer.one_shot = true
	timer.wait_time = lifetime
	timer.timeout.connect(queue_free)
	add_child(timer)
