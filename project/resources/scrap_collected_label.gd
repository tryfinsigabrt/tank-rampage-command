class_name ScrapCollectedLabel extends Node3D

@export
var lifetime:float = 5

@export
var max_scale:float = 1.5

@export
var vertical_speed:float = 5.0

@export
var scrap_amount:int = 5

@onready var _label: Label = %Label

func _ready() -> void:
	_label.text = "+%d" % scrap_amount
	_setup_label_screen_space()
	
	if lifetime <= 0:
		return
		
	queue_free_after_lifetime()
	play_collection_tween()
	
func play_collection_tween() -> void:
	var tween := create_tween() \
		.set_trans(Tween.TRANS_QUART) \
		.set_ease(Tween.EASE_OUT)
	
	tween.set_parallel(true)
	
	if max_scale > 1.0:
		var end_scale := _label.scale * max_scale
		tween.tween_property(_label, "scale", end_scale, lifetime)
	
	if vertical_speed > 0:
		var viewport_height := get_viewport().get_visible_rect().size.y
		var vertical_pixels := viewport_height * (vertical_speed / 100.0)
		var end_position := _label.global_position + Vector2.UP * vertical_pixels * lifetime
		tween.tween_property(_label, "global_position", end_position, lifetime)
		
	tween.tween_property(_label, "modulate:a", 0.0, lifetime)


func _setup_label_screen_space() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(camera):
		return

	_label.top_level = true
	_label.reset_size()
	_label.pivot_offset = _label.size * 0.5

	var screen_position := camera.unproject_position(global_position)
	_label.global_position = screen_position - _label.size * 0.5

func queue_free_after_lifetime() -> void:
	var timer:Timer = Timer.new()
	timer.name = "LifetimeTimer"
	timer.autostart = true
	timer.one_shot = true
	timer.wait_time = lifetime
	timer.timeout.connect(queue_free)
	add_child(timer)
