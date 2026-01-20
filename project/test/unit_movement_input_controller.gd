class_name UnitMovementInputController extends Node

@export
var pawn:Unit

func _ready() -> void:
	if not pawn:
		push_error("%s: No pawn configured - movement disabled!" % name)
		set_physics_process(false)
		set_process(false)
		return
		
func _physics_process(_delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	pawn.move(input_dir)
