class_name HumanArtilleryUnit extends Unit

@export
var turning_speed_degrees: float = 45.0

@export
var aiming_speed_degrees:float = 20.0

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
@onready var turret_pivot: Marker3D = %TurretPivot

var _aim_at_tween:Tween
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

	move_and_slide()


func aim_at(world_location:Vector3) -> void:
	weapon.fire_target = world_location
	
	_pitch_at(world_location)
	_rotate_at(world_location)

func _pitch_at(world_location:Vector3) -> void:
	# Aim degrees based on distance fraction of maximum for aiming
	var dist:float = global_position.distance_to(world_location)
	var dist_fraction:float = dist / weapon.max_distance_range.y
	
	# Need to negate since negative is up
	var target_angle:float = -rotation_angle_v_distance_fraction.sample_baked(dist_fraction)

	# Calculate the angle between current quat and target rotation quat
	var current_rotation:Vector3 = turret_pivot.rotation_degrees
	var angle_delta:float = target_angle - current_rotation.x
	var angle_delta_mag:float = absf(angle_delta)
	
	# Calculate duration (Time = Angular Distance / Speed)
	if absf(angle_delta_mag) < 0.01: 
		return 
		
	var duration: float = angle_delta_mag / aiming_speed_degrees
		
	if is_instance_valid(_aim_at_tween):
		_aim_at_tween.kill()
		_aim_at_tween = null

	var target_rotation_euler:Vector3 = Vector3(target_angle, current_rotation.y, current_rotation.z)
	
	var tween := create_tween()
	tween.tween_property(turret_pivot, "rotation_degrees", target_rotation_euler, duration)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
	
	_aim_at_tween = tween
	
func _rotate_at(world_location:Vector3) -> void:
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
