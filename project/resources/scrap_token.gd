class_name ScrapToken extends Area3D

@export_range(0, 10, 1)
var originating_team:int

@export_range(1,1e9, 1, "or_greater")
var scrap:int

## Max lifetime before auto freeing
@export
var lifetime:float = 30.0

@export
var rotation_speed_deg:float = 180.0

@onready 
var _visual_root: Node3D = %VisualRoot

func _ready() -> void:
	_spin_token()
	if lifetime > 0:
		var timer:Timer = Timer.new()
		timer.name = "LifetimeTimer"
		timer.autostart = true
		timer.one_shot = true
		timer.wait_time = lifetime
		timer.timeout.connect(delete)
		add_child(timer)

func _spin_token() -> void:
	var tween := _visual_root.create_tween()
	tween.set_loops()
	tween.tween_property(_visual_root, "rotation_degrees:y",
		 rotation.y + rotation_speed_deg, 1.0).as_relative()
	
func _on_body_entered(body: Node3D) -> void:
	var unit:Unit = body as Unit
	if not unit:
		return
	
	SignalBus.on_scrap_collected.emit(self, unit)
	
	delete()

func delete() -> void:
	queue_free()
