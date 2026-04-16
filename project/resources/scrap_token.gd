class_name ScrapToken extends Area3D

@export_range(0, 10, 1)
var originating_team:int

@export_range(1,1e9, 1, "or_greater")
var scrap:int


func _on_body_entered(body: Node3D) -> void:
	var unit:Unit = body as Unit
	if not unit:
		return
	
	SignalBus.on_scrap_collected.emit(self, unit)
	
	queue_free()
