class_name HumanArtilleryUnit extends Unit

@export
var turning_speed_degrees: float = 45.0

@export
var aiming_speed_degrees:float = 20.0

@export
var aim_turning_speed_degrees: float = 90.0

## Rotation angle to put on turret vs the max firing distance fraction
@export
var rotation_angle_v_distance_fraction:Curve

@onready var collision: CollisionShape3D = %Collision
@onready var visual_root: Node3D = %VisualRoot
@onready var health_stat: HealthStat = %HealthStat
@onready var weapon_trace: Marker3D = %WeaponTrace
@onready var _weapon: Weapon = %Weapon
@onready var ui: Node3D = %UI
@onready var game_unit_navigation: GameUnitNavigation = %GameUnitNavigation

@export
var turret_rotation_node:Node3D

@export
var barrel_pitch_node:Node3D

var _aim_at_tween:Tween
var _yaw_reset_tween:Tween
var _rotate_aim_tween:Tween

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
	# Negative as "forward" is -z as we are using right-handed OpenGL-style coordinate system
	var movement_direction := -input_direction_3.z * visual_root.global_basis.z
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
	weapon.fire_target = world_location
	
	_rotate_gun_at(world_location)
	#_rotate_body_at(world_location)

func _rotate_gun_at(world_location:Vector3) -> void:
	# Aim degrees based on distance fraction of maximum for aiming
	var dist:float = global_position.distance_to(world_location)
	var dist_fraction:float = dist / weapon.max_distance_range.y
	
	# Need to negate since negative is up
	var target_pitch_angle:float = deg_to_rad(
		-rotation_angle_v_distance_fraction.sample_baked(dist_fraction))

	# Pitch
	var current_pitch_rotation:Vector3 = barrel_pitch_node.rotation
	var pitch_angle_delta:float = angle_difference(current_pitch_rotation.x, target_pitch_angle)
	var pitch_angle_delta_mag:float = absf(pitch_angle_delta)
	var change_pitch:bool = pitch_angle_delta_mag >= 0.01
	
	#Yaw
	var turret_rotation_transform:Transform3D = turret_rotation_node.global_transform
	var current_rotation:Vector3 = turret_rotation_transform.basis.get_euler()
	var current_yaw:float = current_rotation.y
	# use_model_front=true orients +Z toward the target instead of -Z,
	# which is needed because the VisualRoot 180° Y flip makes the barrel's
	# forward direction map to +Z in TurretPivot's local frame.
	var target_transform: Transform3D = turret_rotation_transform.looking_at(world_location, Vector3.UP, true)
	var target_rotation_euler:Vector3 = target_transform.basis.get_euler()
	var target_yaw:float = target_rotation_euler.y
	var yaw_diff:float = angle_difference(current_yaw, target_yaw)
	var yaw_diff_mag:float = absf(yaw_diff)
	var change_yaw:bool =  yaw_diff_mag >= 0.01
	
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
		var target_yaw_rotation_euler:Vector3 = Vector3(current_rotation.x, target_yaw, current_rotation.z)
		
		tween.tween_property(turret_rotation_node, "global_rotation", target_yaw_rotation_euler, yaw_duration)
		
	if change_pitch:
		# Convert desired local pitch to a full global euler target.
		# global_basis = parent_global_basis * local_basis, so:
		# global_euler = (parent_basis * Basis.from_euler(desired_local)).get_euler()
		var parent_basis: Basis = barrel_pitch_node.get_parent().global_transform.basis
		
		# Determine the barrel's local rotation state after the yaw tween completes
		var post_yaw_local:Vector3
		if barrel_pitch_node == turret_rotation_node and change_yaw:
			# Yaw tween will set global_rotation to (current_x, target_yaw, current_z).
			# Reverse that into local space to get the post-yaw local euler.
			var post_yaw_global_basis := Basis.from_euler(
				Vector3(current_rotation.x, target_yaw, current_rotation.z))
			post_yaw_local = (parent_basis.inverse() * post_yaw_global_basis).get_euler()
		else:
			post_yaw_local = barrel_pitch_node.rotation
		
		# Replace only the pitch component, then convert back to global
		var desired_local := Vector3(target_pitch_angle, post_yaw_local.y, post_yaw_local.z)
		var target_pitch_rotation_euler:Vector3 = (parent_basis * Basis.from_euler(desired_local)).get_euler()
		var pitch_duration: float = pitch_angle_delta_mag / deg_to_rad(aiming_speed_degrees)
		
		tween.tween_property(barrel_pitch_node, "global_rotation", target_pitch_rotation_euler, pitch_duration)
	
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
	# Already resetting the yaw, let it finish
	if is_instance_valid(_yaw_reset_tween) and _yaw_reset_tween.is_running():
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
		
func shoot() -> void:
	_weapon.fire()

func get_fire_global_position() -> Vector3:
	return weapon_trace.global_position
	
func get_fire_global_forward() -> Vector3:	
	# VisualRoot has a 180° Y rotation to flip the model to face -Z (Godot forward).
	# WeaponTrace inherits that flip, so its global basis.z is already negated.
	# Multiplying by visual_root's local basis cancels the 180° out
	var orig_basis:Basis = weapon_trace.global_basis
	var corrected_basis:Basis = visual_root.transform.basis
	var final_basis:Basis = orig_basis * corrected_basis
	return -final_basis.z

func get_fire_global_right() -> Vector3:
	var orig_basis:Basis = weapon_trace.global_basis
	var corrected_basis:Basis = visual_root.transform.basis
	var final_basis:Basis = orig_basis * corrected_basis
	return final_basis.x

func get_fire_global_up() -> Vector3:
	return weapon_trace.global_basis.y
	
func _is_moving() -> bool:
	return game_unit_navigation.enabled

func _die(damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	died.emit(damage_params)
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _on_took_damage(damage_params: DamageParameters) -> void:
	damaged.emit(damage_params)
	if health_stat.is_dead:
		_die(damage_params)

func _update_render() -> void:
	visual_root.visible = render
	ui.visible = render

func _get_health_stat() -> HealthStat:
	return health_stat

func _get_weapon() -> Weapon:
	return _weapon
