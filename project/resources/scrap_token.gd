class_name ScrapToken extends Area3D

@export_range(0, 10, 1)
var originating_team:int

@export_range(1,1e9, 1, "or_greater")
var scrap:int

## Max lifetime before auto freeing
@export
var lifetime:float = 30.0

func _ready() -> void:
	if lifetime > 0:
		var timer:Timer = Timer.new()
		timer.name = "LifetimeTimer"
		timer.autostart = true
		timer.one_shot = true
		timer.wait_time = lifetime
		timer.timeout.connect(delete)
		add_child(timer)

func _on_body_entered(body: Node3D) -> void:
	var unit:Unit = body as Unit
	if not unit:
		return
	
	SignalBus.on_scrap_collected.emit(self, unit)
	
	delete()

func delete() -> void:
	queue_free()
