class_name CameraYawTracker extends Node

@export
var target_node:Node3D

var _camera:RTSCamera
	
func _ready() -> void:
	assert(target_node, "%s: Target node not set" % name)
	if not target_node:
		queue_free()
		
	var player:Player = get_tree().get_first_node_in_group(Groups.Player) as Player
	if not player:
		if not Groups.is_precompiler_running(self):
			push_error("%s: No player node in scene - camera positioning not available" % name)
		queue_free()
		return
	
	await NodeUtils.ensure_ready(player)	
	_camera = player.camera
	if _camera:
		_camera.camera_changed.connect(_camera_changed)
		_camera_changed.call_deferred(~0)
	else:
		push_error("%s: Could not get RTSCamera from player!" % name)
		
func _camera_changed(flags:int) -> void:
	if not (flags & RTSCamera.YAW_UPDATED):
		return
		
	# Match camera rotation yaw to rts camera yaw
	var new_rotation:Vector3 = target_node.global_rotation
	new_rotation.y = _camera.global_rotation.y
	
	target_node.global_rotation = new_rotation
