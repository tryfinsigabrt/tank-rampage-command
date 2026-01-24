extends Node3D

@onready var camera: Camera3D = %Camera

func _ready() -> void:
	if visible:
		camera.make_current()
		
func _on_visibility_changed() -> void:
	if visible:
		camera.make_current()
