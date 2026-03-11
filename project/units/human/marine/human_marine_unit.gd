class_name HumanMarineUnit extends Unit

@export_range(1.0,360.0, 0.1)
var turning_speed_degrees:float = 180.0

@export
var idle_animation_velocity_threshold:float = 0.001

@onready var health_stat: HealthStat = %HealthStat
@onready var collision: CollisionShape3D = %Collision
@onready var visual_root: Node3D = %VisualRoot
@onready var fire_position: Marker3D = %FirePosition
@onready var _weapon: Weapon = %Weapon
@onready var game_unit_navigation: GameUnitNavigation = %GameUnitNavigation
@onready var animation: MarineAnimation = %MarineAnimation

func _is_alive() -> bool:
	return health_stat.is_alive

func _physics_process(delta: float) -> void:
	collision.disabled = not is_visible_in_tree()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Transition back to idle when movement has effectively stopped.
	if _is_alive() and animation.state == MarineAnimation.State.RUN:
		var horizontal_speed_sq := Vector2(velocity.x, velocity.z).length_squared()
		if horizontal_speed_sq < idle_animation_velocity_threshold:
			animation.idle()
		#else:
			#print("%s: VELOCITY: sq=%f; v=%s" % [name, horizontal_speed_sq, velocity])
	
# TODO: Some of this can be moved to unit base class or separate component
func move(input_direction:Vector2, speed_override:float = -1.0) -> void:
	animation.run()

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
	if movement_direction:
		velocity.x = movement_direction.x * speed
		velocity.z = movement_direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
# TODO: Some of this can be moved to unit base class or separate component
func aim_at(world_location:Vector3) -> void:
	# TODO:
	look_at(world_location)
	
	#var aim_direction:Vector3 = (world_location - fire_position.global_position).normalized()
	#
	#var heading:Vector3 = get_fire_global_forward()
	#var projected_forward_vector:Vector2 = Vector2(heading.x, heading.z)
	#var projected_aim_dir_turret:Vector2 = Vector2(aim_direction.x, aim_direction.z)
	
	#Check if we are almost there
	#var angle:float = rad_to_deg(aim_dir_turret.angle_to(forward_vector))
	#if absf(angle) > turret_aim_tolerance_deg:
	#if projected_aim_dir_turret.length() > turret_aim_tolerance:
		#var rotation_dir:float = -projected_forward_vector.cross(projected_aim_dir_turret)
		#turret.rotate_turret(rotation_dir)
	#
	#var aim_pitch:float = aim_direction.y
	## Technically this is not an angle but using some small value to avoid jitter
	#if absf(aim_pitch) > pitch_tolerance:
		#barrel.pitch_barrel(aim_pitch)
	
func shoot() -> void:
	#print("%s: SHOOT!" % name)
	animation.shoot()
	_weapon.fire()
	
	# TODO: We should have a blended animation so enemy can shoot while moving
	# This can probably be done in the animation tree blend space
	SignalBus.on_unit_move_canceled.emit(self, game_unit_navigation.current_target)

func get_fire_global_position() -> Vector3:
	return fire_position.global_position

# For the directions use the marine forward because these are used for LOS and gun isn't always at "ready" position	
func get_fire_global_forward() -> Vector3:
	## Positive as we rotated around
	#var orig_basis:Basis = fire_position.global_basis
	#var corrected_basis:Basis = visual_root.transform.basis
	#var final_basis:Basis = orig_basis * corrected_basis
	#return -final_basis.z
	return global_forward

func get_fire_global_right() -> Vector3:
	#return fire_position.global_basis.x
	return global_right

func get_fire_global_up() -> Vector3:
	#return fire_position.global_basis.y
	return global_up
	
func _is_moving() -> bool:
	return game_unit_navigation.enabled

func _update_render() -> void:
	visual_root.visible = render

func _die(damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	animation.die()
	collision.disabled = true
	died.emit(damage_params)
	
	# Delay so can see visuals
	# TODO: Get animation notification when complete
	await get_tree().create_timer(2.0).timeout
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(damage_params: DamageParameters) -> void:
	damaged.emit(damage_params)
	if health_stat.is_dead:
		_die(damage_params)

func _get_health_stat() -> HealthStat:
	return health_stat

func _get_weapon() -> Weapon:
	return _weapon
