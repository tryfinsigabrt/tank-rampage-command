class_name RTSCamera extends Node3D

const YAW_UPDATED:int = 1
const POSITION_UPDATED:int = 1 << 1
const ZOOM_UPDATED:int = 1 << 2

signal camera_changed(flags:int)

# Zoom done on the camera
@onready var camera: Camera3D = %Camera
# Camera "boom"/rig is for translation
@onready var camera_boom: Marker3D = %CameraRig
# Separate camera tilt node for future pitching up/down - right now just sets the initial 45 degree rotation
@onready var camera_tilt: Marker3D = %CameraTilt


@export var make_current_if_visible:bool = true

## Enable mouse capture in viewport on supported platforms
## On web, mouse capture isn't supported so this value is effectively false for that platform
@export var confine_mouse_to_viewport:bool = true

@export var fov:float = 10.0
@export var pos_y:float = 3.0
@export var rot_y:float = -45.0
@export var pos_z:float = 100.0

## Pixels to trigger pan on screen edge
@export var camera_pan_margin_pixels:float = 5.0
@export var camera_pan_speed:Vector2 = Vector2(20.0, 100.0)
@export var camera_drag_pan_speed:float = 0.25
@export var camera_movement_smoothing:float = 12.0
@export var camera_rotation_speed:float = 1.0
@export var camera_zoom_speed:float = 100
@export var camera_zoom_mouse_multiplier:int = 5
@export var camera_zoom_range:Vector2 = Vector2(10.0, 300.0)

var _camera_movement_velocity:Vector3 = Vector3.ZERO
var _camera_target_movement_velocity:Vector3 = Vector3.ZERO
var _camera_current_zoom_speed:float = 0.0
var _camera_total_zoom:float = 0.0
var _mouse_zoom:int = 0
var _drag_panning:bool = false
var _drag_pan_delta:Vector2 = Vector2.ZERO

var _change_flags:int

var zoom:float:
	set(value):
		# Reset so input value is absolute zoom
		var camera_pos:Vector3 = camera.position
		camera_pos.z = 0.0
		camera.position = camera_pos
		
		_camera_current_zoom_speed = clampf(value, camera_zoom_range.x, camera_zoom_range.y)
		_camera_total_zoom = 0.0
		_apply_zoom_velocity()
	get:
		return _camera_total_zoom

#region public methods
func capture_mouse(capture:bool) -> void:
	#MOUSE_MODE_CONFINED not supported on web
	if confine_mouse_to_viewport and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED if capture else Input.MOUSE_MODE_VISIBLE
	
func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CONFINED if not  OS.has_feature("web") else true
	
func make_camera_current() -> void:
	camera.make_current()
	capture_mouse(true)
	
func pan_camera(_delta:float) -> void:
	if not is_mouse_captured() or _drag_panning:
		return
		
	var viewport := get_viewport()
	var viewport_size:Vector2 = viewport.get_visible_rect().size
	var adjusted_camera_move_speed:float = remap(
		_camera_total_zoom,
		camera_zoom_range.x, camera_zoom_range.y,
		camera_pan_speed.x, camera_pan_speed.y
	)
	
	var mouse_pos:Vector2 = viewport.get_mouse_position()
	
	if Input.is_action_pressed("camera_move_left") or mouse_pos.x < camera_pan_margin_pixels:
		_camera_target_movement_velocity.x = -adjusted_camera_move_speed
	elif Input.is_action_pressed("camera_move_right") or mouse_pos.x > viewport_size.x - camera_pan_margin_pixels:
		_camera_target_movement_velocity.x = adjusted_camera_move_speed
		
	if Input.is_action_pressed("camera_move_forward") or mouse_pos.y < camera_pan_margin_pixels:
		_camera_target_movement_velocity.z = -adjusted_camera_move_speed
	elif Input.is_action_pressed("camera_move_backward") or mouse_pos.y > viewport_size.y - camera_pan_margin_pixels:
		_camera_target_movement_velocity.z = adjusted_camera_move_speed

func rotate_camera(delta:float) -> void:
	var updated:bool = false
	if Input.is_action_pressed("camera_rotate_right"):
		global_rotation.y -= camera_rotation_speed * delta
		updated = true
	if Input.is_action_pressed("camera_rotate_left"):
		global_rotation.y += camera_rotation_speed * delta
		updated = not updated
		
	if updated:
		_change_flags |= YAW_UPDATED

	
func zoom_camera(delta:float) -> void:
	if Input.is_action_pressed("camera_zoom_in"):
		_camera_current_zoom_speed -= camera_zoom_speed * delta
	elif Input.is_action_pressed("camera_zoom_out"):
		_camera_current_zoom_speed += camera_zoom_speed * delta
	elif _mouse_zoom: # Mouse wheel events not captured in _process
		_camera_current_zoom_speed += _mouse_zoom * camera_zoom_speed * delta


func drag_pan_camera(delta:float) -> void:
	if not _drag_panning or _drag_pan_delta.is_zero_approx():
		return

	var zoom_ratio := inverse_lerp(camera_zoom_range.x, camera_zoom_range.y, _camera_total_zoom)
	var adjusted_drag_pan_speed := lerpf(camera_drag_pan_speed * 0.25, camera_drag_pan_speed, zoom_ratio)
	var drag := _drag_pan_delta * adjusted_drag_pan_speed / maxf(delta, 0.001)
	_camera_target_movement_velocity += Vector3(-drag.x, 0.0, -drag.y)
	_drag_pan_delta = Vector2.ZERO
		
#endregion

#region public

func move_to(global_planar_pos:Vector3) -> void:
	var new_global_pos := Vector3(
		global_planar_pos.x,
		global_position.y,
		global_planar_pos.z
	)
	
	global_position = new_global_pos
	
	# Reset camera boom offset
	camera_boom.position = Vector3.ZERO
	
	# Just set all flags for safety
	camera_changed.emit(~0)
	
#endregion

#region overrides
func _ready() -> void:
	_setup_camera()
	if make_current_if_visible and is_visible_in_tree():
		make_camera_current()
	
func _process(delta: float) -> void:
	_change_flags = 0
	
	if Input.is_action_just_pressed("camera_primary_button"):
		capture_mouse(true)

	_camera_target_movement_velocity = Vector3.ZERO
		
	pan_camera(delta)
	drag_pan_camera(delta)
	rotate_camera(delta)
	zoom_camera(delta)
	
	_apply_movement_velocity(delta)
	_apply_zoom_velocity()
	
	if _change_flags:
		camera_changed.emit(_change_flags)

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_released("pause"):
		capture_mouse(false)
	# Special handling for mouse wheel as at least in the editor it is not getting reported in _process for "action_pressed"
	elif event is InputEventMouseButton:
		if event.is_action("camera_zoom_in"):
			_mouse_zoom = -camera_zoom_mouse_multiplier
		elif event.is_action("camera_zoom_out"):
			_mouse_zoom = camera_zoom_mouse_multiplier
		elif event.is_action_pressed("camera_drag_pan"):
			_drag_panning = true
			_drag_pan_delta = Vector2.ZERO
		elif event.is_action_released("camera_drag_pan"):
			_drag_panning = false
			_drag_pan_delta = Vector2.ZERO
	elif event is InputEventMouseMotion and _drag_panning:
		_drag_pan_delta += event.relative
	
#endregion

#region privates	
func _on_visibility_changed() -> void:
	if make_current_if_visible and visible:
		make_camera_current()
		
func _setup_camera() -> void:
	camera_tilt.position.y = pos_y
	camera_tilt.rotation.x = deg_to_rad(rot_y)
	
	# Translate in local space
	_camera_total_zoom = pos_z
	camera.fov = fov
	camera.translate_object_local(Vector3(0.0, 0.0, pos_z))
	
func _apply_movement_velocity(delta: float) -> void:
	var weight := 1.0 - exp(-camera_movement_smoothing * delta)
	_camera_movement_velocity = _camera_movement_velocity.lerp(_camera_target_movement_velocity, weight)

	if _camera_movement_velocity.is_zero_approx():
		return

	camera_boom.translate_object_local(_camera_movement_velocity * delta)
	
	_change_flags |= POSITION_UPDATED

func _apply_zoom_velocity() -> void:
	if is_zero_approx(_camera_current_zoom_speed):
		return
	var calculated_zoom:float = camera.position.z + _camera_current_zoom_speed
	# Only apply zoom if within range
	if calculated_zoom > camera_zoom_range.x and calculated_zoom < camera_zoom_range.y:
		_camera_total_zoom += _camera_current_zoom_speed
		camera.translate_object_local(Vector3(0.0, 0.0, _camera_current_zoom_speed))
		
	_camera_current_zoom_speed = 0.0
	_mouse_zoom = 0
	
	_change_flags |= ZOOM_UPDATED

#endregion
