class_name GameUnitNavigation extends Node

var _unit:Unit
var _current_target_position: Vector3
var _target_reached:bool = true

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

@export
var distance_threshold:float = 4.0

@export
var alignment_turn_threshold:float = 0.92

@export
var alignment_forward_threshold:float = 0.6

func _ready() -> void:
	_unit = get_parent() as Unit
	if not _unit:
		push_error("%s: Parent node=%s is not a unit" % [name, get_parent()])
		set_enabled(false)
		return
	SignalBus.on_unit_move_issued.connect(_on_unit_move_issued)

func _on_unit_move_issued(unit:Unit, target: Vector3) -> void:
	if unit != _unit:
		return
	move_to(target)
	
func move_to(target:Vector3) -> void:
	print_debug("%s: move_to - target=%s" % [name, target])
	
	_current_target_position = target
	navigation_agent_3d.target_position = target
	_target_reached = false
	
func set_enabled(enabled:bool) -> void:
	set_physics_process(enabled)
	set_process(enabled)		

func _physics_process(_delta: float) -> void:
	var next_position := navigation_agent_3d.get_next_path_position()
	# TODO: Maybe this needs to be "body.global_position"
	var current_position := _unit.global_position
	
	if next_position.distance_squared_to(current_position) <= distance_threshold * distance_threshold:
		_emit_target_reached()
		return
		
	var direction := current_position.direction_to(next_position)
	var forward_vector := _unit.global_forward
	
	# FIXME: Need a negative sign as the human_tank body is backwards but reverting makes it not move at all
	# as have to fix the backwards nature of the tank movement itself in the move function and the movement_input_controller
	var alignment:float = -direction.dot(forward_vector)
	var unit_move_dir:Vector2 = Vector2.ZERO
	if alignment < alignment_turn_threshold:
		unit_move_dir.x = 1.0 * signf(forward_vector.cross(direction).y)
	if alignment >= alignment_forward_threshold:
		unit_move_dir.y = -1.0
		
	unit_move_dir = unit_move_dir.normalized()
	
	if OS.is_stdout_verbose():
		print_verbose("%s: issue move to for %s: %s -> %s (dir=%s); alignment=%f" % [name, _unit, current_position, next_position, unit_move_dir, alignment])
	
	_unit.move(unit_move_dir)


func _on_navigation_agent_3d_navigation_finished() -> void:
	_emit_target_reached()
	
func _emit_target_reached() -> void:
	if not _target_reached:
		print_debug("%s: Target Reached - unit=%s; pos=%s; target=%s" % [name, _unit.name, _unit.global_position, _current_target_position])
		_target_reached = true
		SignalBus.on_destination_reached.emit(_unit, _current_target_position)
