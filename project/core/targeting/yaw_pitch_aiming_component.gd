class_name YawPitchAimingComponent extends Node

const ComponentName:StringName = &"YawPitchAimingComponent"

@export
var yaw_root:Node3D

@export
var pitch_root:Node3D

var team_asset:Node3D

@export
var turning_speed_degrees: float = 45.0

@export
var aiming_speed_degrees:float = 20.0

@export
var aim_turning_speed_degrees: float = 90.0

@export
var delta_aim_threshold_degrees:float = 1.0

@export
var pos_dist_sq_reaim_threshold:float = 1.0

## Rotation angle to put on turret vs the max firing distance fractio
## Used for launcher type weapons where there is not a direct firing to the target
@export
var rotation_angle_v_distance_fraction:Curve

## Set to true if mesh +Z faces the target instead of -Z
@export
var use_model_front:bool = false

@export
var move_aim_reset_delay_seconds:float = 60.0

## Clamp pitch relative to resting local rotation (0 degrees).
## Negative values aim upward for assets that use Godot's default forward (-Z).
@export
var min_pitch_degrees:float = -90.0

@export
var max_pitch_degrees:float = 90.0

var _last_aim_target:Vector3 = Vector3.INF
var _last_aim_pos:Vector3 = Vector3.INF

var _delta_aim_threshold_rads:float
var _aim_at_tween:Tween
var _yaw_reset_tween:Tween
var _rotate_aim_tween:Tween
var _last_aim_request_time:float = 0

func aim_at(weapon:Weapon, world_location:Vector3) -> bool:
	_last_aim_request_time = GameManager.game_timer.time_seconds

	# Avoid jitter
	var pos:Vector3 = team_asset.global_position
	if world_location.distance_squared_to(_last_aim_target) < pos_dist_sq_reaim_threshold and \
		pos.distance_squared_to(_last_aim_pos) < pos_dist_sq_reaim_threshold:
			return false
	
	_last_aim_target = world_location
	_last_aim_pos = pos
		
	weapon.fire_target = world_location

	_rotate_gun_at(weapon, world_location)
	
	return true
	
func get_fire_alignment_basis() -> Basis:
	var reference_up := team_asset.global_basis.y.normalized()
	# Turret is rotated 180 due to parent visual_root so negate the basis vector +Z is model forward
	var fire_forward := (yaw_root.global_basis.z).slide(reference_up).normalized()

	# Right-handed frame: right = forward x up
	var fire_right := fire_forward.cross(reference_up).normalized()

	# Recompute up so the basis is orthonormal
	var fire_up := fire_right.cross(fire_forward).normalized()

	var basis_forward:Vector3 = fire_forward if not use_model_front else -fire_forward
	return Basis(fire_right, fire_up, basis_forward)
	
#region Component Registration
static func get_component(node: Node, required:bool = true) -> YawPitchAimingComponent:
	return Components.get_component(ComponentName, node, required) as YawPitchAimingComponent
		
func _enter_tree() -> void:
	team_asset = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if not team_asset:
		push_error("%s: Not added to tree with a TeamAsset!" % name)
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
#endregion

func _ready() -> void:	
	_delta_aim_threshold_rads = deg_to_rad(delta_aim_threshold_degrees) if delta_aim_threshold_degrees > 0 else 0.0

func _rotate_gun_at(weapon:Weapon, world_location:Vector3) -> void:
	# If a curve is defined use this, otherwise aim at the location
	var target_pitch_angle:float
	
	if rotation_angle_v_distance_fraction:
		# Aim degrees based on distance fraction of maximum for aiming
		var dist:float = team_asset.global_position.distance_to(world_location)
		var dist_fraction:float = dist / weapon.max_distance_range.y
		
		# Need to negate since negative is up
		target_pitch_angle = deg_to_rad(
			-rotation_angle_v_distance_fraction.sample_baked(dist_fraction))
	else:
		var pitch_parent := pitch_root.get_parent() as Node3D
		var to_target_world:Vector3 = world_location - pitch_root.global_position
		if not to_target_world.is_zero_approx():
			# Use elevation over horizontal distance so pitch is independent of current yaw.
			var local_up:Vector3 = pitch_parent.global_basis.y.normalized()
			var vertical_distance:float = to_target_world.dot(local_up)
			var horizontal_distance:float = to_target_world.slide(local_up).length()
			target_pitch_angle = atan2(vertical_distance, horizontal_distance)
		else:
			target_pitch_angle = pitch_root.rotation.x

	#print("%s: TARGET PITCH ANGLE (%s -> %s) -> %.1f" % [name, pitch_root.global_position, world_location, rad_to_deg(target_pitch_angle)])
	
	target_pitch_angle = clampf(
		target_pitch_angle,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)

	# Pitch
	var current_pitch_rotation:Vector3 = pitch_root.rotation
	var current_pitch_angle:float = current_pitch_rotation.x
	var pitch_angle_delta:float = angle_difference(current_pitch_angle, target_pitch_angle)
	var pitch_angle_delta_mag:float = absf(pitch_angle_delta)
	var change_pitch:bool = pitch_angle_delta_mag >= _delta_aim_threshold_rads
	
	#Yaw
	var turret_parent := yaw_root.get_parent() as Node3D
	var current_yaw:float = yaw_root.rotation.y
	var target_yaw:float = current_yaw
	var yaw_diff:float = 0.0
	var yaw_diff_mag:float = 0.0
	var change_yaw:bool = false
	var to_target_local:Vector3 = turret_parent.to_local(world_location) - yaw_root.position
	to_target_local.y = 0.0
	if not to_target_local.is_zero_approx():
		var forward_local:Vector3 = Vector3.BACK if use_model_front else Vector3.FORWARD
		target_yaw = forward_local.signed_angle_to(to_target_local.normalized(), Vector3.UP)
		yaw_diff = angle_difference(current_yaw, target_yaw)
		yaw_diff_mag = absf(yaw_diff)
		change_yaw = yaw_diff_mag >= _delta_aim_threshold_rads
	
	#print("%s: Pitch: %.1f -> %1.f - Yaw: %.1f -> %1.f - Pos=%s - Target=%s" % \
	# [name, rad_to_deg(current_pitch_angle), rad_to_deg(target_pitch_angle),  rad_to_deg(current_yaw), rad_to_deg((target_yaw)), global_position, world_location])
	
	# Calculate duration (Time = Angular Distance / Speed)
	if not change_pitch and not change_yaw:
		return 
		
	# Kill the reset yaw tween if valid
	if is_instance_valid(_yaw_reset_tween):
		_yaw_reset_tween.kill()
		_yaw_reset_tween = null
		
	if is_instance_valid(_aim_at_tween):
		_aim_at_tween.kill()
		_aim_at_tween = null

	var tween := create_tween() \
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
		
	# First rotate yaw if it needs to change and then pitch
	if change_yaw:
		var yaw_duration: float = yaw_diff_mag / deg_to_rad(aim_turning_speed_degrees)
		var final_yaw := target_yaw

		# Using tween method as lerp_angle is more resilient to wrap around problems than tweening the euler rotation
		# since we only modify yaw here
		tween.tween_method(
			func(weight: float) -> void:
				var yaw := lerp_angle(current_yaw, final_yaw, weight)
				var new_rotation := yaw_root.rotation
				new_rotation.y = yaw
				yaw_root.rotation = new_rotation,
			0.0,
			1.0,
			yaw_duration
		)
		
	if change_pitch:
		var pitch_duration: float = pitch_angle_delta_mag / deg_to_rad(aiming_speed_degrees)
		var end_pitch:float = current_pitch_angle + pitch_angle_delta

		# Using tween method as lerp_angle is more resilient to wrap around problems than tweening the euler rotation
		# since we only modify pitch here
		tween.tween_method(
			func(weight: float) -> void:
				var pitch := lerp_angle(current_pitch_angle, end_pitch, weight)
				var new_rotation := pitch_root.rotation
				new_rotation.x = pitch
				pitch_root.rotation = new_rotation,
			0.0,
			1.0,
			pitch_duration
		)
	
	_aim_at_tween = tween

var global_up:Vector3:
	get: return team_asset.global_up if team_asset.has_method("global_up") else team_asset.global_basis.y
	
func _rotate_body_at(world_location:Vector3) -> void:
	var current_quat := team_asset.global_transform.basis.get_rotation_quaternion()
	var target_transform := team_asset.global_transform.looking_at(world_location, global_up)
	var target_quat := target_transform.basis.get_rotation_quaternion()

	# Calculate the angle between current quat and target rotation quat
	var angle_rad := current_quat.angle_to(target_quat)
	var angle_deg := rad_to_deg(angle_rad)
	
	# Calculate duration (Time = Angular Distance / Speed)
	# Avoid division by zero if already looking at the target
	if angle_deg < 0.01: 
		return 
		
	var duration := angle_deg / turning_speed_degrees
		
	if is_instance_valid(_rotate_aim_tween):
		_rotate_aim_tween.kill()
		_rotate_aim_tween = null

	var tween := create_tween()
	tween.tween_property(self, "quaternion", target_quat, duration)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
	
	_rotate_aim_tween = tween
	
func reset_turret_yaw() -> void:
	if _is_recently_aiming():
		return

	# Already resetting the yaw, let it finish
	if is_instance_valid(_yaw_reset_tween) and _yaw_reset_tween.is_running():
		return
	
	# Don't reset if in middle of aiming
	if is_instance_valid(_aim_at_tween) and _aim_at_tween.is_running():
		return
	
	_yaw_reset_tween = null
	var current_rotation: Vector3 = yaw_root.rotation
	if abs(current_rotation.y) < 0.01:
		return

	var tween := create_tween() \
		.set_trans(Tween.TRANS_QUART) \
		.set_ease(Tween.EASE_OUT)
	
	var angle_diff_degrees:float = absf(rad_to_deg(angle_difference(current_rotation.y, 0.0)))
	var duration:float = angle_diff_degrees / aim_turning_speed_degrees
	
	var target_rotation: Vector3 = Vector3(current_rotation.x, 0.0, current_rotation.z)
	tween.tween_property(yaw_root, "rotation", target_rotation, duration)
	_yaw_reset_tween = tween

func _is_recently_aiming() -> bool:
	return GameManager.game_timer.time_seconds - _last_aim_request_time <= move_aim_reset_delay_seconds
