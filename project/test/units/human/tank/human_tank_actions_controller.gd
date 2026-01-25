extends Node3D

@onready var follow_camera: FollowCamera = $FollowCamera

func _ready() -> void:
	if visible:
		follow_camera.make_camera_current()
		
func _on_visibility_changed() -> void:
	if visible:
		follow_camera.make_camera_current()
