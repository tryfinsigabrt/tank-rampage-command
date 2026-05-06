class_name HumanArtilleryUnit extends Unit

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

## Rotation angle to put on turret vs the max firing distance fraction
@export
var rotation_angle_v_distance_fraction:Curve

## Set to true if mesh +Z faces the target instead of -Z
@export
var use_model_front:bool = false

@export
var move_aim_reset_delay_seconds:float = 60.0

@onready var collision: CollisionShape3D = %Collision
@onready var visual_root: Node3D = %VisualRoot
@onready var health_stat: HealthStat = %HealthStat
@onready var weapon_trace: Marker3D = %WeaponTrace
@onready var _weapon: Weapon = %Weapon
@onready var ui: Node3D = %UI
@onready var game_unit_navigation: GameUnitNavigation = %GameUnitNavigation
@onready var _team_comp: TeamComponent = %TeamComponent

@export
var turret_rotation_node:Node3D

@export
var barrel_pitch_node:Node3D

var _last_aim_target:Vector3 = Vector3.INF
var _last_aim_pos:Vector3 = Vector3.INF

var _delta_aim_threshold_rads:float
var _aim_at_tween:Tween
var _yaw_reset_tween:Tween
var _rotate_aim_tween:Tween
var _last_aim_request_time:float = 0

func _ready() -> void:
	super._ready()
	
	_delta_aim_threshold_rads = deg_to_rad(delta_aim_threshold_degrees) if delta_aim_threshold_degrees > 0 else 0.0
	
func _is_alive() -> bool:
	return health_stat.is_alive
	
func _physics_process(delta: float) -> void:
	collision.disabled = not is_visible_in_tree()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
## Provides the screen direction to instruct the unit to move to
func move(input_direction:Vector2, speed_override:float = -1.0) -> void:
	if input_direction.is_zero_approx():
		return
	# Move forward/back always proceeds along forward vector 
	# and left/right rotates in place
	var input_direction_3:Vector3 = Vector3(input_direction.x, 0, input_direction.y)
	
	# Positive rotation is ccw but we want right (+x) to turn model cw so negate
	var rotation_dir:float = signf(-input_direction.x)
	var rot:float = deg_to_rad(turning_speed_degrees) * get_physics_process_delta_time() * rotation_dir
	
	# Rotate the whole character so that the collider rotates too
	rotate_y(rot)

	var speed:float = movement_speed if speed_override <= 0.0 else speed_override
	var movement_direction := -input_direction_3.z * global_forward
	var projected_movement:Vector2 = Vector2(movement_direction.x, movement_direction.z).normalized()
	
	if projected_movement:
		velocity.x = projected_movement.x * speed
		velocity.z = projected_movement.y * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Reset any turret raw so we are pointing forward
	_reset_turret_yaw()
	
	move_and_slide()

func aim_at(world_location:Vector3) -> void:
	_last_aim_request_time = GameManager.game_timer.time_seconds

	# Avoid jitter
	var pos:Vector3 = global_position
	if world_location.distance_squared_to(_last_aim_target) < pos_dist_sq_reaim_threshold and \
		pos.distance_squared_to(_last_aim_pos) < pos_dist_sq_reaim_threshold:
			return
	
	_last_aim_target = world_location
	_last_aim_pos = pos
	
	weapon.fire_target = world_location
	
	_rotate_gun_at(world_location)

func _rotate_gun_at(world_location:Vector3) -> void:
	# Aim degrees based on distance fraction of maximum for aiming
	var dist:float = global_position.distance_to(world_location)
	var dist_fraction:float = dist / weapon.max_distance_range.y
	
	# Need to negate since negative is up
	var target_pitch_angle:float = deg_to_rad(
		-rotation_angle_v_distance_fraction.sample_baked(dist_fraction))

	# Pitch
	var current_pitch_rotation:Vector3 = barrel_pitch_node.rotation
	var current_pitch_angle:float = current_pitch_rotation.x
	var pitch_angle_delta:float = angle_difference(current_pitch_angle, target_pitch_angle)
	var pitch_angle_delta_mag:float = absf(pitch_angle_delta)
	var change_pitch:bool = pitch_angle_delta_mag >= _delta_aim_threshold_rads
	
	#Yaw
	var turret_parent := turret_rotation_node.get_parent() as Node3D
	var current_yaw:float = turret_rotation_node.rotation.y
	var target_yaw:float = current_yaw
	var yaw_diff:float = 0.0
	var yaw_diff_mag:float = 0.0
	var change_yaw:bool = false
	var to_target_local:Vector3 = turret_parent.to_local(world_location) - turret_rotation_node.position
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
				var new_rotation := turret_rotation_node.rotation
				new_rotation.y = yaw
				turret_rotation_node.rotation = new_rotation,
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
				var new_rotation := barrel_pitch_node.rotation
				new_rotation.x = pitch
				barrel_pitch_node.rotation = new_rotation,
			0.0,
			1.0,
			pitch_duration
		)
	
	_aim_at_tween = tween
	
func _rotate_body_at(world_location:Vector3) -> void:
	var current_quat := global_transform.basis.get_rotation_quaternion()
	var target_transform := global_transform.looking_at(world_location, global_up)
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
	
func _reset_turret_yaw() -> void:
	if _is_recently_aiming():
		return

	# Already resetting the yaw, let it finish
	if is_instance_valid(_yaw_reset_tween) and _yaw_reset_tween.is_running():
		return
	
	# Don't reset if in middle of aiming
	if is_instance_valid(_aim_at_tween) and _aim_at_tween.is_running():
		return
	
	_yaw_reset_tween = null
	var current_rotation: Vector3 = turret_rotation_node.rotation
	if abs(current_rotation.y) < 0.01:
		return

	var tween := create_tween() \
		.set_trans(Tween.TRANS_QUART) \
		.set_ease(Tween.EASE_OUT)
	
	var angle_diff_degrees:float = absf(rad_to_deg(angle_difference(current_rotation.y, 0.0)))
	var duration:float = angle_diff_degrees / aim_turning_speed_degrees
	
	var target_rotation: Vector3 = Vector3(current_rotation.x, 0.0, current_rotation.z)
	tween.tween_property(turret_rotation_node, "rotation", target_rotation, duration)
	_yaw_reset_tween = tween

func _is_recently_aiming() -> bool:
	return GameManager.game_timer.time_seconds - _last_aim_request_time <= move_aim_reset_delay_seconds
		
func shoot() -> void:
	await _weapon.fire()

func get_fire_global_position() -> Vector3:
	return weapon_trace.global_position
	
func _get_fire_alignment_basis() -> Basis:
	var reference_up := global_basis.y.normalized()
	# Turret is rotated 180 due to parent visual_root so negate the basis vector +Z is model forward
	var fire_forward := (turret_rotation_node.global_basis.z).slide(reference_up).normalized()

	# Right-handed frame: right = forward x up
	var fire_right := fire_forward.cross(reference_up).normalized()

	# Recompute up so the basis is orthonormal
	var fire_up := fire_right.cross(fire_forward).normalized()

	var basis_forward:Vector3 = fire_forward if not use_model_front else -fire_forward
	return Basis(fire_right, fire_up, basis_forward)

func get_fire_global_forward() -> Vector3:
	return -_get_fire_alignment_basis().z

func get_fire_global_right() -> Vector3:
	return _get_fire_alignment_basis().x

func get_fire_global_up() -> Vector3:
	return _get_fire_alignment_basis().y

func _is_moving() -> bool:
	return game_unit_navigation.enabled

func _die(damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	died.emit(damage_params)
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _on_took_damage(damage_params: DamageParameters) -> void:
	damaged.emit(damage_params)
	if health_stat.is_dead:
		_die(damage_params)

func _update_render(in_render:bool) -> void:
	visual_root.visible = in_render
	ui.visible = in_render

func _get_health_stat() -> HealthStat:
	return health_stat

func _get_weapon() -> Weapon:
	return _weapon

func _get_team_component() -> TeamComponent:
	return _team_comp
