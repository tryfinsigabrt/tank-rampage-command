class_name AttackAction extends Node3D

var controlled_unit:Unit
var targeted_unit:Unit
var targeted_location:Vector3

# TODO: This will vary per unit so should get the min fire interval from the controlled unit
# and maybe this will be a multiplier on top of that
# Same with the fire range
@export
var fire_interval:float = 2.0

@export
var fire_range:Vector2 = Vector2(10.0, 2000.0)

@export_range(0.0,180.0, 0.1)
var fire_alignment_tolerance_deg:float = 15.0

@export
var ray_cast_dest_offset:float = 5.0

var _fire_timer:Timer

signal _los_signal

var _check_los:bool
var _has_los:bool

func _ready() -> void:
	if not controlled_unit:
		push_warning("%s: No controlled unit set - no attack will occur" % name)
		return
		
	_move_into_attack_range()
	
	_fire_timer = Timer.new()
	_fire_timer.name = &"FireTimer"
	_fire_timer.autostart = false
	_fire_timer.one_shot = true
	_fire_timer.wait_time = fire_interval
	_fire_timer.timeout.connect(_on_fire)
	add_child(_fire_timer)

func _move_into_attack_range() -> void:
	var attack_position:Vector3 = _get_target_position()
	var to_attack:Vector3 = attack_position - controlled_unit.get_fire_global_position()
	var attack_dir:Vector3 = to_attack.normalized()
	# Move back by 2 * min attack range
	var move_target:Vector3 = attack_position - attack_dir * fire_range.x * 2 
	SignalBus.on_unit_move_issued.emit(controlled_unit, move_target)

func _process(_delta: float) -> void:
	if not _is_valid():
		queue_free()
		return
		
	_aim()
	var fire_timer_running:bool = not _fire_timer.is_stopped()
	var in_range:bool = _is_in_range()
	
	if in_range and _check_los:
		_has_los = _check_target_los()
		if _has_los:
			_los_signal.emit()
		
	if in_range and not fire_timer_running:
		_fire_and_schedule()
	elif not in_range and fire_timer_running:
		_fire_timer.stop()
		
func _aim() -> void:
	var target:Vector3 = _get_target_position()
	controlled_unit.aim_at(target)
	
func _is_in_range() -> bool:
	var my_position:Vector3 = controlled_unit.get_fire_global_position()
	var target_position:Vector3 = _get_target_position()
	var to_target:Vector3 = target_position - my_position
	var dist_sq:float = to_target.length_squared()
	
	if dist_sq < fire_range.x * fire_range.x or dist_sq > fire_range.y * fire_range.y:
		DebugDraw3D.draw_ray(my_position, to_target, sqrt(dist_sq), Color.RED)
		if OS.is_stdout_verbose():
			print_verbose("%s: in_range=FALSE(DIST); my_position=%s; target=%s; to_target=%s; dist=%f" % [name, my_position, targeted_location, to_target, sqrt(dist_sq)])
	
		return false
	
	# Check angle alignment
	var aim_direction:Vector3 = controlled_unit.get_fire_global_forward()
	#DebugDraw3D.draw_ray(my_position, aim_direction, 10000.0, Color.BLUE)

	var heading:Vector3 = to_target / maxf(dist_sq, 0.001)
	var angle:float = rad_to_deg(aim_direction.angle_to(heading))
	if angle > fire_alignment_tolerance_deg:
		DebugDraw3D.draw_ray(my_position, to_target, sqrt(dist_sq), Color.ORANGE)
		if OS.is_stdout_verbose():
			print_verbose("%s: in_range=FALSE(ANGLE); my_position=%s; target=%s; to_target=%s; dist=%f; angle=%f" % [name, my_position, targeted_location, to_target, sqrt(dist_sq), angle])
	
		return false
	
	DebugDraw3D.draw_ray(my_position, to_target, sqrt(dist_sq), Color.GREEN)
	if OS.is_stdout_verbose():
		print_verbose("%s: in_range=TRUE; my_position=%s; target=%s; to_target=%s; dist=%f; angle=%f" % [name, my_position, targeted_location, to_target, sqrt(dist_sq), angle])
	
	return true
	
func _is_target_valid() -> bool:
	return not targeted_unit or is_instance_valid(targeted_unit)
	
func _check_target_los() -> bool:
	var space_state := get_world_3d().direct_space_state
	
	var from:Vector3 = controlled_unit.get_fire_global_position()
	var to:Vector3 = _get_target_position()
	var to_to:Vector3 = to - from
	var dir := to_to.normalized()

	if to_to.length_squared() > ray_cast_dest_offset * ray_cast_dest_offset:
		to -= dir * ray_cast_dest_offset
	
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.collision_mask = Collisions.CompositeMasks.visibility
	ray_params.from = from
	ray_params.to = to
	
	if targeted_unit:
		ray_params.exclude = [targeted_unit]
	
	var has_los:bool = space_state.intersect_ray(ray_params).is_empty()
	
	if OS.is_debug_build():
		DebugDraw3D.draw_ray(from, dir, (to - from).length(), Color.BLUE if has_los else Color.MAGENTA, 1.0)
	return has_los
	
func _get_target_position() -> Vector3:
	return targeted_unit.global_position if targeted_unit else targeted_location
	
func _is_valid() -> bool:
	return is_instance_valid(controlled_unit) and _is_target_valid()

func _fire_and_schedule() -> void:
	await _fire()
	_fire_timer.start()
	
func _on_fire() -> void:
	if not _is_valid():
		queue_free()
		return
	_fire_and_schedule()

func _fire() -> void:
	_has_los = _check_target_los()
	if not _has_los:
		_check_los = true
		await _los_signal
		_check_los = false
		
	controlled_unit.shoot()
