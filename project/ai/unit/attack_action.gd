class_name AttackAction extends Node3D

enum MoveBehavior
{
	ALWAYS,
	IF_OUT_RANGE,
	NEVER
}

var weapon:Weapon

var _weapon_controller:WeaponController
var _controlled_asset:Node3D
# If controlled asset is a unit
var _controlled_unit:Unit
var _use_target_node_bounds:bool

var targeted_node:Node3D:
	set(value):
		if is_instance_valid(value) and value.is_in_group(Groups.TeamAsset):
			_node_was_targeted = true
			targeted_node = value
			_use_target_node_bounds = targeted_node.has_method("get_global_bounds")
		else:
			# Make sure we didn't fail the group check
			assert(not is_instance_valid(value), "%s: targeted_node=%s not in expected group!" % [name, StringUtils.safe_name(value)])
			
			_node_was_targeted = false
			targeted_node = null
			_use_target_node_bounds = false
	get:
		return targeted_node if is_instance_valid(targeted_node) else null
			
var _node_was_targeted:bool

var targeted_location:Vector3
var move_into_range:MoveBehavior = MoveBehavior.ALWAYS
var _range_move_target:Vector3 = Vector3.INF

# TODO: This will vary per unit so should get the min fire interval from the controlled unit
# and maybe this will be a multiplier on top of that
# Same with the fire range
@export
var fire_interval:float = 2.0

@export
var fire_range:Vector2 = Vector2(10.0, 500.0)

@export
var fire_max_angle_deg_v_range_fraction:Curve

@export
var ray_cast_dest_offset:float = 5.0

## Time out of range to auto-expire the behavior
## Only applicable for NEVER MoveBehavior
@export
var auto_expire_out_of_range:float = 5.0

var _time_out_of_range:float = 0.0

var _fire_timer:Timer

signal _los_signal

var _check_los:bool
var _has_los:bool

func _ready() -> void:
	if not weapon:
		push_warning("%s: No weapon set - no attack will occur" % name)
		return
	
	_weapon_controller = weapon.weapon_controller
	if not _weapon_controller:
		push_warning("%s: Weapon=%s has no WeaponController - no attack will occur" % [name, weapon.name])
		return
		
	_controlled_asset = _weapon_controller.get_team_asset()
	_controlled_unit = _controlled_asset as Unit
	
	fire_interval = weapon.cooldown_time_range.x
	fire_range = weapon.ideal_fire_range if weapon.prefer_close_shots else weapon.total_fire_range
		
	_move_into_attack_range()
	
	_fire_timer = Timer.new()
	_fire_timer.name = &"FireTimer"
	_fire_timer.autostart = false
	_fire_timer.one_shot = true
	_fire_timer.wait_time = fire_interval
	_fire_timer.timeout.connect(_on_fire)
	add_child(_fire_timer)

var firing:bool:
	get: return not _fire_timer.is_stopped()
	
func _exit_tree() -> void:
	if SignalBus.on_destination_reached.is_connected(_move_finished):
		SignalBus.on_destination_reached.disconnect(_move_finished)
	if SignalBus.on_unit_move_canceled.is_connected(_move_finished):
		SignalBus.on_unit_move_canceled.disconnect(_move_finished)
		
	# Cancel active move if it's not complete
	if is_instance_valid(_controlled_unit) and _range_move_target != Vector3.INF:
		if LogUtils.debug:
			print_debug("%s: %s cancel target move to %s" % [name, _controlled_unit.name, _range_move_target])
		SignalBus.on_unit_move_canceled.emit(_controlled_unit, _range_move_target)
		
func _move_into_attack_range() -> void:
	_range_move_target = Vector3.INF
	
	# Only supported for units with the move into range behavior set
	if not _controlled_unit or move_into_range == MoveBehavior.NEVER:
		return
		
	var my_position:Vector3 = _weapon_controller.get_fire_global_position()
	var attack_position:Vector3 = _get_target_position()
	var to_attack:Vector3 = attack_position - my_position
	var attack_dir:Vector3 = to_attack.normalized()
	
	if move_into_range == MoveBehavior.ALWAYS:
		# Move back by 2 * min attack range
		var buffer:float = _get_move_buffer_dist()
		var min_dist:float = minf(fire_range.x + buffer, fire_range.y - buffer)
			
		var ideal_dist:float = min_dist * 2.0 if fire_range.x / fire_range.y < 0.1 else min_dist
		_range_move_target = attack_position - attack_dir * ideal_dist
		_move_to_ranged_target()
	
	# Out of range could be too close or too far away
	elif move_into_range == MoveBehavior.IF_OUT_RANGE:
		var dist:float = to_attack.length()
		# Too far?
		var diff:float = dist - fire_range.y
		var move:bool = diff > 0
		if not move:
			# Too close?
			diff = dist - fire_range.x
			move = diff < 0
		if move:
			# Add a buffer
			var buffer:float = _get_move_buffer_dist()
			diff += signf(diff) * buffer
			_range_move_target = my_position + attack_dir * diff
			_move_to_ranged_target()

func _get_move_buffer_dist() -> float:
	var bounds_size := _controlled_unit.get_global_bounds().size
	var buffer:float = maxf(bounds_size.x, bounds_size.z) * 2.0
	return buffer
	
func _move_to_ranged_target() -> void:
	assert(_controlled_unit, "%s: Unexpected call to move for non-unit asset=%s" % [name, StringUtils.safe_name(_controlled_asset)])
	
	if not SignalBus.on_destination_reached.is_connected(_move_finished):
		SignalBus.on_destination_reached.connect(_move_finished)
	if not SignalBus.on_unit_move_canceled.is_connected(_move_finished):
		SignalBus.on_unit_move_canceled.connect(_move_finished)
		
	SignalBus.on_unit_move_issued.emit(_controlled_unit, _range_move_target)

func _move_finished(in_unit:Unit, _in_target_position:Vector3) -> void:
	if in_unit != _controlled_unit:
		return
	_range_move_target = Vector3.INF
	
func _process(delta: float) -> void:
	if not is_valid():
		queue_free()
		return
		
	_aim()
	var fire_timer_running:bool = not _fire_timer.is_stopped()
	var in_range:bool = _is_in_range()
	
	if move_into_range == MoveBehavior.NEVER:
		if in_range:
			_time_out_of_range = 0
		else:
			_time_out_of_range += delta
			if _time_out_of_range > auto_expire_out_of_range:
				queue_free()
				return
	
	if in_range and _check_los:
		_has_los = _check_target_los()
		if _has_los:
			_los_signal.emit()
		
	if in_range and not fire_timer_running:
		@warning_ignore("missing_await")
		_fire_and_schedule()
	elif not in_range and fire_timer_running:
		_fire_timer.stop()
		_weapon_controller.shoot_intent_toggled.emit(false)
		
	# If not in range and not currently moving then move into range
	if not in_range and move_into_range != MoveBehavior.NEVER and _range_move_target == Vector3.INF:
		_move_into_attack_range()
		
func _aim() -> void:
	var target:Vector3 = _get_target_position()
	_weapon_controller.aim_at(target)
	
func _is_in_range() -> bool:
	var my_position:Vector3 = _weapon_controller.get_fire_global_position()
	var target_position:Vector3 = _get_target_position()
	var to_target:Vector3 = target_position - my_position
	var dist_sq:float = to_target.length_squared()
	
	if dist_sq < fire_range.x * fire_range.x or dist_sq > fire_range.y * fire_range.y:
		if OS.is_stdout_verbose():
			DebugDraw3D.draw_ray(my_position, to_target, sqrt(dist_sq), Color.RED)
			print_verbose("%s: in_range=FALSE(DIST); my_position=%s; target=%s; to_target=%s; dist=%f" % [name, my_position, target_position, to_target, sqrt(dist_sq)])
	
		return false
	
	# Check angle alignment
	var aim_direction:Vector3 = _weapon_controller.get_fire_global_forward()
	#DebugDraw3D.draw_ray(my_position, aim_direction, 10000.0, Color.BLUE)

	var heading:Vector3 = to_target / maxf(dist_sq, 0.001)
	var angle:float = rad_to_deg(aim_direction.angle_to(heading))
	var dist:float = sqrt(dist_sq)
	var range_fraction:float = inverse_lerp(fire_range.x, fire_range.y, dist)
	var max_angle_deg:float = fire_max_angle_deg_v_range_fraction.sample_baked(range_fraction)
	
	if angle > max_angle_deg:
		if OS.is_stdout_verbose():
			DebugDraw3D.draw_ray(my_position, to_target, dist, Color.ORANGE)
			print_verbose("%s: in_range=FALSE(ANGLE); my_position=%s; target=%s; to_target=%s; dist=%f; angle=%f > %f" % [name, my_position, targeted_location, to_target, dist, angle, max_angle_deg])
	
		return false
	
	if OS.is_stdout_verbose():
		DebugDraw3D.draw_ray(my_position, to_target, dist, Color.GREEN)
		print_verbose("%s: in_range=TRUE; my_position=%s; target=%s; to_target=%s; dist=%f; angle=%f <= %f" % [name, my_position, targeted_location, to_target, dist, angle, max_angle_deg])
	
	return true
	
func _is_target_valid() -> bool:
	return not _node_was_targeted or _is_valid_targeted_node()

func _is_valid_targeted_node() -> bool:
	var node := targeted_node
	if not node:
		return false
	# If target node has a health component and is dead then return false
	var health := HealthStat.get_component(node, false)
	if health and health.is_dead:
		return false
	elif node.is_queued_for_deletion():
		return false
		
	# Target node must be visible to us
	return TeamComponent.first_is_visible_to_second_asset(node, _controlled_asset)
	
func _check_target_los() -> bool:
	# If targeting a node make sure it is still valid
	if _node_was_targeted and not _is_valid_targeted_node():
		return false
		
	if weapon and not weapon.require_los:
		return true
		
	var space_state := get_world_3d().direct_space_state
	
	var from:Vector3 = _weapon_controller.get_fire_global_position()
	var to:Vector3 = _get_target_position()
	var to_to:Vector3 = to - from
	var dir := to_to.normalized()

	if to_to.length_squared() > ray_cast_dest_offset * ray_cast_dest_offset:
		to -= dir * ray_cast_dest_offset
	
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.collision_mask = Collisions.CompositeMasks.visibility
	ray_params.from = from
	ray_params.to = to
	
	if targeted_node:
		ray_params.exclude = [targeted_node]
	
	var has_los:bool = space_state.intersect_ray(ray_params).is_empty()
	
	if OS.is_stdout_verbose():
		DebugDraw3D.draw_ray(from, dir, (to - from).length(), Color.BLUE if has_los else Color.MAGENTA, 1.0)
	return has_los
	
func _get_target_position() -> Vector3:
	if targeted_node:
		# Prefer to target the center of the target instead of it's global_position which is usually the bottom
		if _use_target_node_bounds:
			var bounds:AABB = targeted_node.get_global_bounds()
			return bounds.get_center()
		else:
			return targeted_node.global_position
	return targeted_location
	
func is_valid() -> bool:
	return is_instance_valid(_weapon_controller) and _is_target_valid()

func _fire_and_schedule() -> void:
	await _fire()
	
	_weapon_controller.shoot_intent_toggled.emit(true)
	_fire_timer.start()
	
func _on_fire() -> void:
	if not is_valid():
		queue_free()
		return
		
	@warning_ignore("missing_await")
	_fire_and_schedule()

func _fire() -> void:
	_has_los = _check_target_los()
	if not _has_los:
		_check_los = true
		await _los_signal
		_check_los = false
		
	@warning_ignore("missing_await")
	_weapon_controller.shoot()
