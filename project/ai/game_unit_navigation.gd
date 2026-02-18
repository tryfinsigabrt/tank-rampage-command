class_name GameUnitNavigation extends Node

var _unit:Unit
var _current_target_position: Vector3
var _target_reached:bool = true

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var stuck_detector: StuckDetector = $StuckDetector

@export
var distance_threshold:float = 4.0

@export
var alignment_turn_threshold:float = 0.92

@export
var alignment_forward_threshold:float = 0.6

@export
var avoidance_enabled:bool = true

var enabled:bool:
	get:
		return is_physics_processing()

func _ready() -> void:
	_unit = get_parent() as Unit
	if not _unit:
		push_error("%s: Parent node=%s is not a unit" % [name, get_parent()])
		return
	SignalBus.on_unit_move_issued.connect(_on_unit_move_issued)
	SignalBus.on_unit_move_canceled.connect(_on_unit_move_canceled)
	
	stuck_detector.unit = _unit
	set_enabled(false)

func _on_unit_move_issued(unit:Unit, target: Vector3) -> void:
	if unit != _unit:
		return
	move_to(target)
	
func move_to(target:Vector3) -> void:
	if LogUtils.verbose:
		print_debug("%s: move_to - target=%s" % [name, target])
	
	_current_target_position = target
	navigation_agent_3d.target_position = target
	
	if not _is_at_target(target):
		_target_reached = false
		stuck_detector.goal_position = target
		
		set_enabled(true)
	else:
		_emit_target_reached()
	
func set_enabled(in_enabled:bool) -> void:
	set_physics_process(in_enabled)
	set_process(in_enabled)
	
	if in_enabled:
		if avoidance_enabled:
			navigation_agent_3d.avoidance_enabled = true
			navigation_agent_3d.max_speed = _unit.movement_speed
			navigation_agent_3d.set_velocity_forced(_unit.velocity)
	else:
		stuck_detector.reset()
		navigation_agent_3d.avoidance_enabled = false

func _is_at_target(next_position: Vector3) -> bool:
	var current_position := _unit.global_position
	return next_position.distance_squared_to(current_position) <= distance_threshold * distance_threshold

func _physics_process(delta: float) -> void:
	var next_position := navigation_agent_3d.get_next_path_position()
	
	#print_debug("%s: NEXT POSITION=%s" % [name, next_position])
	
	if _is_at_target(next_position):
		_emit_target_reached()
		return
	
	# TODO: Maybe this needs to be "body.global_position"
	var current_position := _unit.global_position
	
	if not stuck_detector.sample(delta, current_position, next_position):
		# Complete move if detect are stuck
		_emit_target_reached()
		return
	
	var velocity:Vector3 = current_position.direction_to(next_position) * _unit.movement_speed
	if navigation_agent_3d.avoidance_enabled:
		navigation_agent_3d.velocity = velocity
	else:
		_move_unit(velocity)

func _move_unit(velocity:Vector3) -> void:
	if velocity.is_zero_approx():
		return
		
	var speed:float = velocity.length()
	var direction:Vector3 = velocity / speed
		
	var forward_vector := _unit.global_forward
	var alignment:float = direction.dot(forward_vector)
	var unit_move_dir:Vector2 = Vector2.ZERO
	if alignment < alignment_turn_threshold:
		# We expect positive x to cause cw rotation
		# which is opposite to Godot have ccw be positive so we negate
		unit_move_dir.x = -1.0 * signf(forward_vector.cross(direction).y)
	if alignment >= alignment_forward_threshold:
		# Negative y moves up in the direction of our target
		unit_move_dir.y = -1.0
		
	unit_move_dir = unit_move_dir.normalized()
	
	_unit.move(unit_move_dir, speed)
	
func _on_unit_move_canceled(unit: Unit, target_position:Vector3) -> void:
	if unit != _unit:
		return
	
	print_debug("%s: Unit move canceled: %s -> %s" % [name, unit.name, target_position])
	set_enabled(false)
	
func _on_navigation_agent_3d_navigation_finished() -> void:
	_emit_target_reached()
	
func _emit_target_reached() -> void:
	if not _target_reached:
		if LogUtils.verbose:
			print_debug("%s: Target Reached - unit=%s; pos=%s; target=%s" % [name, _unit.name, _unit.global_position, _current_target_position])
		
		_target_reached = true
		set_enabled(false)
		SignalBus.on_destination_reached.emit(_unit, _current_target_position)


#region Avoidance
func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	_move_unit(safe_velocity)

#endregion
