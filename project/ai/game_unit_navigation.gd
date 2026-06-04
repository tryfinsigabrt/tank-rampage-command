class_name GameUnitNavigation extends Node

const ComponentName:StringName = "GameUnitNavigation"

signal move_started(target:Vector3)
signal move_completed(target:Vector3)
signal move_canceled(target:Vector3)

var _unit:Unit
var _current_target_position: Vector3
var _target_reached:bool = true

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var stuck_detector: StuckDetector = $StuckDetector
@onready var simple_navigation: SimpleNavigation = $SimpleNavigation
@onready var avoidance_steering: AvoidanceSteering = $AvoidanceSteering

@export
var distance_threshold:float = 4.0

@export
var alignment_turn_threshold:float = 0.92

@export
var alignment_forward_threshold:float = 0.6

@export
var avoidance_enabled:bool = true

@export
var enable_stuck_detection:bool = true

@export
var enable_simple_nav_fallback:bool = true

@export
var enable_avoidance_steering:bool = true

## Minimum size of x or z component of move velocity to actually issue move
## Avoids flip flopping when components are small
@export
var move_comp_mag_threshold:float = 0.01

var _enabled:bool
var _paused:bool

var enabled:bool:
	get:
		return _enabled
		
var paused:bool:
	get:
		return _paused
	set(value):
		if not enabled or value == _paused:
			return
			
		print_debug("%s: Paused toggled - %s to %s" % [name, StringUtils.safe_name(_unit), value])
		_paused = value
		_set_processing(value)

var current_target:Vector3:
	get:
		return _current_target_position

func _ready() -> void:
	_unit = get_parent() as Unit
	if not _unit:
		push_error("%s: Parent node=%s is not a unit" % [name, get_parent()])
		return
	SignalBus.on_unit_move_issued.connect(_on_unit_move_issued)
	SignalBus.on_unit_move_canceled.connect(_on_unit_move_canceled)
	
	stuck_detector.unit = _unit
	simple_navigation.unit = _unit
	
	avoidance_steering.active = enable_avoidance_steering
	
	set_enabled(false)
	
#region Component Registration
static func get_component(node: Node, required:bool = true) -> GameUnitNavigation:
	return Components.get_component(ComponentName, node, required) as GameUnitNavigation
		
func _enter_tree() -> void:
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
	
#endregion

func _on_unit_move_issued(unit:Unit, target: Vector3) -> void:
	if unit != _unit:
		return
	move_to(target)
	
func move_to(target:Vector3) -> void:
	if LogUtils.verbose:
		print_debug("%s: move_to - unit=%s; target=%s" % [name, _unit.name, target])
	
	_current_target_position = target
	navigation_agent_3d.target_position = target
	
	_target_reached = false
	
	move_started.emit(target)

	if not _is_at_target(target):
		stuck_detector.goal_position = target
		simple_navigation.goal_location = target
		simple_navigation.stop()
		
		set_enabled(true)
	else:
		_emit_target_reached()
	
func set_enabled(in_enabled:bool) -> void:
	_enabled = in_enabled
	_paused = false

	_set_processing(in_enabled)
	
	if LogUtils.verbose:
		print_debug("%s: Navigation toggled - %s to %s" % [name, _unit.name, in_enabled])
	
	if in_enabled:
		if avoidance_enabled:
			Avoidance.apply_avoidance_mask_to(_unit)
			navigation_agent_3d.avoidance_enabled = true
			navigation_agent_3d.max_speed = _unit.movement_speed
			navigation_agent_3d.set_velocity_forced(_unit.velocity)
	else:
		stuck_detector.reset()
		navigation_agent_3d.avoidance_enabled = false
		simple_navigation.stop()

func _set_processing(in_enabled:bool) -> void:
	set_physics_process(in_enabled)
	set_process(in_enabled)
	
func _is_at_target(next_position: Vector3) -> bool:
	var current_position := _unit.global_position
	return next_position.distance_squared_to(current_position) <= distance_threshold * distance_threshold

func _physics_process(delta: float) -> void:
	var next_position:Vector3
	if simple_navigation.active:
		simple_navigation.tick(delta)
		next_position = simple_navigation.next_position
	else:
		next_position = navigation_agent_3d.get_next_path_position()
		
	_on_tick_next_target(delta, next_position)
	
func _on_tick_next_target(delta:float, next_position:Vector3) -> void:	
	#print_debug("%s: NEXT POSITION=%s" % [name, next_position])
	
	if _is_at_target(next_position):
		_emit_target_reached()
		return
	
	# TODO: Maybe this needs to be "body.global_position"
	var current_position := _unit.global_position
	
	if enable_stuck_detection and not stuck_detector.sample(delta, current_position, next_position):
		# Complete move if detect are stuck after trying simple strategy
		if not enable_simple_nav_fallback or simple_navigation.active:
			_emit_target_reached()
		else:
			_start_simple_nav()
		return
		
	var velocity:Vector3 = next_position - current_position
	# Ignore y component and renormalize
	velocity = _get_sanitized_velocity(velocity)
	if not velocity:
		return
	
	velocity = velocity.normalized()
	if avoidance_steering.active:
		avoidance_steering.tick(delta)
		if avoidance_steering.avoidance_heading != Vector3.INF:
			velocity = avoidance_steering.avoidance_heading
			velocity.y = 0.0
			velocity = velocity.normalized()
			
	velocity *= _unit.movement_speed
	
	if navigation_agent_3d.avoidance_enabled:
		navigation_agent_3d.velocity = velocity
	else:
		_move_unit(velocity)

func _start_simple_nav() -> void:
	navigation_agent_3d.avoidance_enabled = false
	simple_navigation.goal_location = current_target
	
	stuck_detector.reset()
	stuck_detector.goal_position = current_target
	
	simple_navigation.start()
	
func _move_unit(velocity:Vector3) -> void:
	var grid_velocity:Vector2 = Vector2(velocity.x, velocity.z)
	if not enabled or grid_velocity.is_zero_approx():
		return
		
	var speed:float = grid_velocity.length()
	var direction:Vector2 = grid_velocity / speed
		
	var forward_vector := _unit.global_forward
	var grid_forward: Vector2 = Vector2(forward_vector.x, forward_vector.z)
	
	var alignment:float = direction.dot(grid_forward)
	var unit_move_dir:Vector2 = Vector2.ZERO
	if alignment < alignment_turn_threshold:
		# We expect positive x to cause cw rotation
		unit_move_dir.x = 1.0 * signf(grid_forward.cross(direction))
	if alignment >= alignment_forward_threshold:
		# Negative y moves up in the direction of our target
		unit_move_dir.y = -1.0
		
	unit_move_dir = unit_move_dir.normalized()
	
	_unit.move(unit_move_dir, speed)
	
func _on_unit_move_canceled(unit: Unit, target_position:Vector3) -> void:
	if unit != _unit:
		return
		
	# Only cancel if target position matches current target
	if not target_position.is_equal_approx(current_target):
		return
	
	if LogUtils.verbose:
		print_debug("%s: Unit move canceled: %s -> %s" % [name, unit.name, target_position])
	_stop_navigation()
	
	move_canceled.emit(target_position)
	
func _on_navigation_agent_3d_navigation_finished() -> void:
	_emit_target_reached()
	
func _emit_target_reached() -> void:
	if not _target_reached:
		if LogUtils.verbose:
			print_debug("%s: Target Reached - unit=%s; pos=%s; target=%s" % [name, _unit.name, _unit.global_position, _current_target_position])
		
		_target_reached = true
		
		_stop_navigation()
		SignalBus.on_destination_reached.emit(_unit, _current_target_position)
		
		move_completed.emit(_current_target_position)

func _stop_navigation() -> void:
	# Clear out horizontal velocity on unit if on floor
	if _unit.is_on_floor():
		_unit.velocity = Vector3(0.0, _unit.velocity.y, 0.0)
	
	set_enabled(false)
	
#region Avoidance
func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	var velocity:Vector3 = _get_sanitized_velocity(safe_velocity)
	if velocity:
		_move_unit(velocity)

func _get_sanitized_velocity(input:Vector3) -> Vector3:
	input.y = 0.0
	if absf(input.x) < move_comp_mag_threshold and absf(input.z) < move_comp_mag_threshold:
		return Vector3.ZERO
	
	return input
	
#endregion

func _on_simple_navigation_destination_reached() -> void:
	_emit_target_reached()
