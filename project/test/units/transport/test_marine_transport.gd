extends Node3D

@onready var transports: Node3D = %Transports

@export var click_to_destroy_transports: bool = false:
	set(value):
		if value == true:
			_destroy_bunkers()

func _destroy_bunkers() -> void:
	if Engine.is_editor_hint() or not transports:
		return
	
	for child in transports.get_children():
		var transport:MarineTransportUnit = child as MarineTransportUnit
		if transport:
			transport.kill()
	
