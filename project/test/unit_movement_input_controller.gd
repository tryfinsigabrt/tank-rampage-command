class_name UnitMovementInputController extends Node

@export
var pawn:CharacterBody3D

@export_range(1.0, 1e9, 0.1, "or_greater")
var movement_speed:float = 15.0

func _ready() -> void:
	if not pawn:
		push_error("%s: No pawn configured - movement disabled!" % name)
		set_physics_process(false)
		set_process(false)
		return
		
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not pawn.is_on_floor():
		pawn.velocity += pawn.get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (pawn.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		pawn.velocity.x = direction.x * movement_speed
		pawn.velocity.z = direction.z * movement_speed
	else:
		pawn.velocity.x = move_toward(pawn.velocity.x, 0, movement_speed)
		pawn.velocity.z = move_toward(pawn.velocity.z, 0, movement_speed)

	pawn.move_and_slide()
