class_name HumanTank extends Unit

@onready var turret: Turret = %Turret
@onready var barrel: Node3D = %Barrel

@export_range(0.0, 1e9, 0.01, "or_greater")
var turret_aim_tolerance_deg:float = 1.0

@export_range(1.0, 1e9, 0.1, "or_greater")
var movement_speed:float = 15.0

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
func move(input_direction:Vector2) -> void:
	var direction := (transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	if direction:
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed)
		velocity.z = move_toward(velocity.z, 0, movement_speed)

	move_and_slide()

func aim_at(world_location:Vector3) -> void:
	# TODO: pitch the barrel
	
	var aim_direction:Vector3 = (world_location - turret.global_position).normalized()
	var forward_vector:Vector3 = global_foward
	
	#Check if we are almost there
	var angle:float = rad_to_deg(aim_direction.angle_to(forward_vector))
	if angle <= turret_aim_tolerance_deg:
		return
	
	var rotation_dir:float = forward_vector.cross(aim_direction).y
	
	turret.rotate_turret(rotation_dir)
	
