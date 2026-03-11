class_name HumanTank extends Unit

@onready var turret: Turret = %Turret
@onready var barrel: TankBarrel = %Barrel
@onready var body: TankBody = %Body
@onready var collision: CollisionShape3D = $Collision
@onready var game_unit_navigation: GameUnitNavigation = $GameUnitNavigation
@onready var health_stat: HealthStat = %HealthStat
@onready var ui: Node3D = %UI

@export_range(0.0, 90.0, 0.01)
var turret_aim_tolerance_deg:float = 1.0

@export_range(0.0, 1.0, 0.001)
var turret_aim_tolerance:float = 0.1

@export_range(0.0, 1.0, 0.001)
var pitch_tolerance:float = 0.01
	
func _is_alive() -> bool:
	return health_stat.is_alive
	
func _physics_process(delta: float) -> void:
	collision.disabled = not is_visible_in_tree()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
func move(input_direction:Vector2, speed_override:float = -1.0) -> void:
	if input_direction.is_zero_approx():
		return
	# Move forward/back always proceeds along forward vector 
	# and left/right rotates in place
	var input_direction_3:Vector3 = Vector3(input_direction.x, 0, input_direction.y)
	
	# Positive rotation is ccw but we want right (+x) to turn model cw so negate
	var rotation_dir:float = signf(-input_direction.x)
	var rot:float = deg_to_rad(body.turning_speed_degrees) * get_physics_process_delta_time() * rotation_dir
	
	# Rotate the whole character so that the collider rotates too
	rotate_y(rot)

	var speed:float = movement_speed if speed_override <= 0.0 else speed_override
	# Negative as "forward" is -z as we are using right-handed OpenGL-style coordinate system
	var movement_direction := -input_direction_3.z * body.global_basis.z
	if movement_direction:
		velocity.x = movement_direction.x * speed
		velocity.z = movement_direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func aim_at(world_location:Vector3) -> void:	
	var aim_direction:Vector3 = (world_location - barrel.fire_position_marker.global_position).normalized()
	
	var heading:Vector3 = get_fire_global_forward()
	var projected_forward_vector:Vector2 = Vector2(heading.x, heading.z)
	var projected_aim_dir_turret:Vector2 = Vector2(aim_direction.x, aim_direction.z)
	
	#Check if we are almost there
	#var angle:float = rad_to_deg(aim_dir_turret.angle_to(forward_vector))
	#if absf(angle) > turret_aim_tolerance_deg:
	if projected_aim_dir_turret.length() > turret_aim_tolerance:
		var rotation_dir:float = -projected_forward_vector.cross(projected_aim_dir_turret)
		turret.rotate_turret(rotation_dir)
	
	var aim_pitch:float = aim_direction.y
	# Technically this is not an angle but using some small value to avoid jitter
	if absf(aim_pitch) > pitch_tolerance:
		barrel.pitch_barrel(aim_pitch)

func shoot() -> void:
	barrel.shoot()
	
func get_fire_global_position() -> Vector3:
	return barrel.fire_position_marker.global_position
	
func get_fire_global_forward() -> Vector3:
	# Positive as we rotated around
	var orig_basis:Basis = barrel.fire_position_marker.global_basis
	var corrected_basis:Basis = body.transform.basis
	var final_basis:Basis = orig_basis * corrected_basis
	return -final_basis.z
	#return -barrel.global_basis.z

func get_fire_global_right() -> Vector3:
	#var final_basis:Basis = barrel.global_basis * body.transform.basis
	#return final_basis.x
	return barrel.fire_position_marker.global_basis.x

func get_fire_global_up() -> Vector3:
	return barrel.global_basis.y
	
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
	body.visible = render
	ui.visible = render

func _get_health_stat() -> HealthStat:
	return health_stat

func _get_weapon() -> Weapon:
	return barrel.weapon
