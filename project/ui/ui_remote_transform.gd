class_name UIRemoteTransform extends RemoteTransform3D

var _camera:RTSCamera

var _original_rotation:Vector3

func _enter_tree() -> void:
	update_position = true
	update_rotation = true
	update_scale = false
	_original_rotation = rotation
	
func _ready() -> void:
	var player:Player = get_tree().get_first_node_in_group(Groups.Player) as Player
	if not player:
		push_warning("%s: No player node in scene - camera positioning not available" % name)
		return
	
	await NodeUtils.ensure_ready(player)	
	_camera = player.camera
	if _camera:
		_camera.camera_changed.connect(_camera_changed)
		_camera_changed(~0)
	else:
		push_error("%s: Could not get RTSCamera from player!" % name)
		
func _camera_changed(flags:int) -> void:
	if not (flags & RTSCamera.YAW_UPDATED):
		return
		
	# Match camera rotation yaw to rts camera yaw
	var new_rotation:Vector3 = global_rotation + _original_rotation
	new_rotation.y = _camera.rotation.y
	
	global_rotation = new_rotation
