class_name HumanTank extends Unit

@onready var turret: Turret = %Turret
@onready var barrel: TankBarrel = %Barrel
@onready var body: TankBody = %Body
@onready var collision: CollisionShape3D = $Collision

@export_range(0.0, 90.0, 0.01)
var turret_aim_tolerance_deg:float = 1.0

@export_range(0.0, 1.0, 0.001)
var turret_aim_tolerance:float = 0.1

@export_range(0.0, 1.0, 0.001)
var pitch_tolerance:float = 0.01

@export_range(1.0, 1e9, 0.1, "or_greater")
var movement_speed:float = 15.0
	
func _physics_process(delta: float) -> void:
	collision.disabled = not is_visible_in_tree()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
func move(input_direction:Vector2) -> void:
	# Move forward/back always proceeds along forward vector 
	# and left/right rotates in place
	var input_direction_3:Vector3 = Vector3(input_direction.x, 0, input_direction.y)
	
	# Positive rotation is ccw but we want right (+x) to turn model cw so negate
	var rotation_dir:float = signf(-input_direction.x)
	var rot:float = deg_to_rad(body.turning_speed_degrees) * get_physics_process_delta_time() * rotation_dir
	
	# Rotate the whole character so that the collider rotates too
	rotate_y(rot)

	# Negative as "forward" is -z as we are using right-handed OpenGL-style coordinate system
	var movement_direction := -input_direction_3.z * body.global_basis.z
	if movement_direction:
		velocity.x = movement_direction.x * movement_speed
		velocity.z = movement_direction.z * movement_speed
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed)
		velocity.z = move_toward(velocity.z, 0, movement_speed)

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
