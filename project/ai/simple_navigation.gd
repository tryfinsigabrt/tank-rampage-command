class_name SimpleNavigation extends Node

signal on_destination_reached

## Called when new heading decision occurs - may be the same heading as last time
signal on_next_heading(new_heading:Vector3, dev_angle_deg:float)

## Called when the new heading deviates from previous to avoid an upcoming obstacle
signal on_heading_changed(new_heading:Vector3, dev_angle_deg:float)

@export
var target_distance_threshold:float = 4.0

@export
var raycast_distance:float = 5.0

@export
var raycast_timeout:float = 2.0

@export
var raycast_cone_angle_deg:float = 120.0

@export
var raycast_delta_angle_deg:float = 30.0

@export_flags_3d_physics
var raycast_mask:int = Collisions.Layers.world_static

var unit:Unit
var goal_location:Vector3

var active:bool:
	get:
		return active
		
var next_position:Vector3:
	get:
		return _next_target
		
var _ray_cast_params:PhysicsRayQueryParameters3D
var _ray_count:int

var _current_heading:Vector3
var _target_distance:float
var _prev_raycast_index:int
var _next_target:Vector3
var _current_position:Vector3

var _total_elapsed_time:float = 0.0
var _current_target_time:float = 0.0
var _unit_half_height:float

func start() -> void:
	if not is_instance_valid(unit):
		unit = null
		push_error("%s: Unit is not valid or is null" % name)
		return
		
	if not _ray_cast_params:
		_init_ray_cast_params()
		_unit_half_height = unit.get_bounds().size.y * 0.5
		
	active = true
	_current_heading = Vector3.INF
	_target_distance = 0.0
	_current_target_time = 0.0
	_next_target = Vector3.INF
	_current_position = unit.global_position
	_total_elapsed_time = 0.0
	_prev_raycast_index = -1

func stop() -> void:
	active = false

func tick(delta: float) -> void:
	if not active:
		assert("%s: tick called when inactive unit=%s" % [name, StringUtils.safe_name(unit)])
		return
		
	var new_position:Vector3 = unit.global_position

	if _is_at_target(new_position):
		on_destination_reached.emit()
		stop()
		return
		
	var delta_position:float = new_position.distance_to(_current_position)
	_target_distance += delta_position
	_current_position = new_position
	_total_elapsed_time += delta
	_current_target_time += delta
		
	if _should_choose_new_target(delta):
		_choose_next_target()
		
func _should_choose_new_target(delta:float) -> bool:
	return _next_target == Vector3.INF \
		or _current_target_time >= raycast_timeout \
		or _target_distance >= raycast_distance \
		or _is_at_next_target(delta)
		

func _is_at_next_target(delta:float) -> bool:
	var horizontal_delta := MathUtils.grid_vector(_next_target - _current_position)
	var arrival_distance := maxf(0.1, unit.movement_speed * delta)
	return horizontal_delta.length_squared() <= arrival_distance * arrival_distance
	
func _choose_next_target() -> void:
	_target_distance = 0.0
	_current_target_time = 0.0
	
	var unit_up:Vector3 = unit.global_up
	var unit_forward:Vector3 = unit.global_forward
	
	var cast_position:Vector3 = _current_position + unit_up * _unit_half_height
	var ideal_heading:Vector3 = _current_position.direction_to(goal_location)
	# Change y component to match unit_forward and renormalize
	ideal_heading.y = unit_forward.y
	ideal_heading = ideal_heading.normalized()
	
	var headings:PackedVector3Array
	
	var ideal_target:Vector3 = cast_position + ideal_heading * raycast_distance
	_ray_cast_params.from = cast_position
	
	var space_state := get_viewport().find_world_3d().direct_space_state
	var new_heading:Vector3
	var new_target:Vector3
	var chosen_index:int = -1
	var chosen_angle:float = 0.0
	
	if _ray_cast(space_state, ideal_target):
		chosen_index = 0
		new_heading = ideal_heading
		new_target = ideal_target
	else:
		headings.resize(_ray_count)
		headings[0] = ideal_heading
		
		var angle_step:float = deg_to_rad(raycast_delta_angle_deg)
		var angle:float = 0.0
		
		for i in range(1, _ray_count):
			# Alternate on sides of the direct heading
			angle = -angle
			# Angle is negative about ideal vector for evens
			if i % 2 == 0:
				angle -= angle_step
			else:
				angle += angle_step
				
			var heading:Vector3 = ideal_heading.rotated(unit_up, angle)
			var target:Vector3 = cast_position + heading * raycast_distance
			if _ray_cast(space_state, target):
				new_heading = heading
				new_target = target
				chosen_index = i
				chosen_angle = angle
				break
			headings[i] = new_heading
		
	# Pick one at random if none are viable
	if chosen_index == -1:
		chosen_index = randi_range(0, headings.size() - 1)
		chosen_angle = ceilf(chosen_index / 2.0) * deg_to_rad(raycast_delta_angle_deg) if chosen_index > 0 else 0.0
		if chosen_angle > 0 and chosen_index % 2 == 0:
			chosen_angle = -chosen_angle
			
		new_heading = headings[chosen_index]
		new_target = cast_position + new_heading * raycast_distance
	
	_current_heading = new_heading
	_next_target = new_target
		
	if chosen_index != _prev_raycast_index:
		_prev_raycast_index = chosen_index
		on_heading_changed.emit(new_heading, chosen_angle)
	
	on_next_heading.emit(new_heading, chosen_angle)
	
func _init_ray_cast_params() -> void:
	_ray_count = floori(raycast_cone_angle_deg / raycast_delta_angle_deg) + 1
	
	_ray_cast_params = PhysicsRayQueryParameters3D.new()
	_ray_cast_params.collide_with_areas = false
	_ray_cast_params.collide_with_bodies = true
	_ray_cast_params.collision_mask = raycast_mask
	_ray_cast_params.exclude = [unit.get_rid()]

func _ray_cast(state: PhysicsDirectSpaceState3D, target:Vector3) -> bool:
	_ray_cast_params.to = target
	return state.intersect_ray(_ray_cast_params).is_empty()
	
func _is_at_target(new_position: Vector3) -> bool:
	var projected_new_pos := MathUtils.grid_vector(new_position)
	var projected_goal_pos := MathUtils.grid_vector(goal_location)
	
	return projected_new_pos.distance_squared_to(projected_goal_pos) <= target_distance_threshold * target_distance_threshold
