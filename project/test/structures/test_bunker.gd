extends Node3D

@onready var bunkers: Node3D = %Bunkers

@export var click_to_destroy_bunkers: bool = false:
	set(value):
		if value == true:
			_destroy_bunkers()

func _destroy_bunkers() -> void:
	if Engine.is_editor_hint() or not bunkers:
		return
	
	for child in bunkers.get_children():
		var bunker:BunkerStructure = child as BunkerStructure
		if bunker:
			bunker.health_stat.die()
	
