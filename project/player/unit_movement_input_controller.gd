class_name UnitMovementInputController extends Node

@export
var pawn:Unit

func _ready() -> void:
	if not pawn:
		push_error("%s: No pawn configured - movement disabled!" % name)
		_toggle_controls(false)
		return
	pawn.visibility_changed.connect(_on_pawn_visibility_changed)
	
	if not pawn.is_visible_in_tree():
		print_debug("%s: Disabling input as pawn %s is not visible in tree" % [name, pawn.name])
		_toggle_controls(false)
		return
		
func _on_pawn_visibility_changed() -> void:
	var is_visible:bool = pawn.is_visible_in_tree()
	print_debug("%s: Visibility of pawn %s changed to %s" % [name, pawn.name, is_visible])
	_toggle_controls(is_visible)
	
func _toggle_controls(enabled:bool) -> void:
	set_physics_process(enabled)
	set_process(enabled)
	
# Movement must happen in physics process since we are moving the collider
func _physics_process(_delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	#print_debug("input_dir=%s" % input_dir)
	pawn.move(input_dir)
	
# Aiming can happen in process as it is purely visual
func _process(_delta: float) -> void:
	var rot_dir:int = 0
	if Input.is_action_pressed("rotate_gun_ccw"):
		rot_dir += 1
	if Input.is_action_pressed("rotate_gun_cw"):
		rot_dir -= 1
	
	var pitch_dir:int = 0

	if Input.is_action_pressed("aim_up"):
		pitch_dir += 1
	if Input.is_action_pressed("aim_down"):
		pitch_dir -= 1
	
	var aim_location:Vector3 = Vector3.ZERO
	
	if rot_dir:
		# CCW is positive
		#DebugDraw3D.draw_ray(pawn.get_fire_global_position(), pawn.get_fire_global_right() * rot_dir * 100.0, 100.0, Color.BLUE)
		aim_location += pawn.get_fire_global_position() + rot_dir * pawn.get_fire_global_right() * 100.0
	
	if pitch_dir:
		aim_location.y += pawn.get_fire_global_position().y + pitch_dir * 100.0

	if aim_location:
		pawn.aim_at(aim_location)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		pawn.shoot()
