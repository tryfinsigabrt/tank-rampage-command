extends Node

@export
var enable:bool

@export
var kill_delay:float = 0.2


func _ready() -> void:
	SignalBus.on_unit_selected.connect(_kill)
	SignalBus.on_building_selected.connect(_kill)
	SignalBus.on_structure_selected.connect(_kill)



func _kill(asset:Node3D) -> void:
	if not enable:
		return
		
	var health_stat := HealthStat.get_component(asset, false)
	if not health_stat:
		return

	if kill_delay > 0:
		await get_tree().create_timer(kill_delay, false).timeout
	
	if not is_instance_valid(health_stat) or health_stat.is_dead:
		return
		
	health_stat.die()
