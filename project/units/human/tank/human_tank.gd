class_name HumanTank extends Unit

@onready var turret: Turret = %Turret
@onready var barrel: TankBarrel = %Barrel
@onready var body: TankBody = %Body

@export_range(0.0, 90.0, 0.01)
var turret_aim_tolerance_deg:float = 1.0

@export_range(0.0, 1.0, 0.001)
var turret_aim_tolerance:float = 0.1

@export_range(0.0, 1.0, 0.001)
var pitch_tolerance:float = 0.01

@export_range(1.0, 1e9, 0.1, "or_greater")
var movement_speed:float = 15.0

func _orientation_basis() -> Node3D:
	return body
	
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
func move(input_direction:Vector2) -> void:
	# Move forward/back always proceeds along forward vector 
	# and left/right rotates in place
	var input_direction_3:Vector3 = Vector3(input_direction.x, 0, input_direction.y)
	
	var direction := (transform.basis * input_direction_3).normalized()
	var rotation_dir:float = signf(-direction.x)
	body.turn(rotation_dir)

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
	var aim_direction:Vector3 = (world_location - turret.global_position).normalized()
	
	#var barrel_dir:Vector3 = -barrel.global_transform.basis.z
	#var forward_vector:Vector2 = Vector2(barrel_dir.x, barrel_dir.z)
	var v:Vector3 = global_forward
	var forward_vector:Vector2 = Vector2(v.x, v.z)
	var aim_dir_turret:Vector2 = Vector2(aim_direction.x, aim_direction.z)
	
	#Check if we are almost there
	#var angle:float = rad_to_deg(aim_dir_turret.angle_to(forward_vector))
	#if absf(angle) > turret_aim_tolerance_deg:
	if aim_dir_turret.length() > turret_aim_tolerance:
		var rotation_dir:float = -forward_vector.cross(aim_dir_turret)
		turret.rotate_turret(rotation_dir)
	
	var aim_pitch:float = aim_direction.y
	# Technically this is not an angle but using some small value to avoid jitter
	if absf(aim_pitch) > pitch_tolerance:
		barrel.pitch_barrel(aim_pitch)

func shoot() -> void:
	barrel.shoot()
