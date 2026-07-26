class_name AvoidanceSteering extends Node

@export
var active:bool

@export
var update_rate:float = 0.2

@export
var update_rate_variance:float = 0.05

@export
var avoidance_min_time:float = 2.0

@export
var avoidance_radius:float = 20.0

@export
var raycast_cone_angle_deg:float = 120.0

@export
var raycast_delta_angle_deg:float = 30.0

var _unit:Unit

var _time_to_next_update:float = 0.0
var _avoidance_time_rem:float = 0.0

var avoidance_heading:Vector3 = Vector3.INF
		
var _ray_cast_params:PhysicsRayQueryParameters3D
var _ray_count:int
var _unit_half_height:float
var _unit_forward_length:float
var _initialized:bool

func _initialize() -> void:
	_initialized = true
	
	_unit = Groups.get_parent_in_group(self, Groups.Unit) as Unit
	assert(_unit, "%s: Added to a non unit root" % name)
	if not _unit:
		return
	
	var bounds_size:Vector3 = _unit.get_bounds().size
	
	_unit_half_height = bounds_size.y * 0.5
	# Assuming unit faces down Z axis
	_unit_forward_length = bounds_size.z * 0.5
	
	_init_ray_cast_params()
	
func tick(delta: float) -> void:
	if active and not _initialized:
		_initialize()
	if not active or not is_instance_valid(_unit):
		assert("%s: tick called when inactive or with invalid unit unit=%s" % [name, StringUtils.safe_name(_unit)])
		return
		
	_time_to_next_update -= delta
	_avoidance_time_rem -= delta
	if _avoidance_time_rem <= 0.0:
		avoidance_heading = Vector3.INF
		
	if _time_to_next_update <= 0.0:
		_update()
		
func _init_ray_cast_params() -> void:
	_ray_count = floori(raycast_cone_angle_deg / raycast_delta_angle_deg) + 1
	
	_ray_cast_params = PhysicsRayQueryParameters3D.new()
	_ray_cast_params.collide_with_areas = false
	_ray_cast_params.collide_with_bodies = true
	_ray_cast_params.collision_mask = Collisions.Layers.dynamic_obstacle
	_ray_cast_params.exclude = [_unit.get_rid()]
		
func _update() -> void:
	_time_to_next_update = randf_range(update_rate - update_rate_variance, update_rate + update_rate_variance)
	
	var unit_up:Vector3 = _unit.global_up
	var unit_forward:Vector3 = _unit.global_forward
	var unit_position:Vector3 = _unit.global_position
	var cast_position:Vector3 = unit_position + unit_up * _unit_half_height + unit_forward * _unit_forward_length
		
	var ideal_target:Vector3 = cast_position + unit_forward * avoidance_radius
	_ray_cast_params.from = cast_position
	
	var space_state := get_viewport().find_world_3d().direct_space_state
	
	if _ray_cast(space_state, ideal_target):
		# No avoidance required
		return
		
	var angle_step:float = deg_to_rad(raycast_delta_angle_deg)
	var angle:float = 0.0
	var heading:Vector3 = unit_forward
	
	for i in range(1, _ray_count):
		# Alternate on sides of the direct heading
		angle = -angle
		# Angle is negative about ideal vector for evens
		if i % 2 == 0:
			angle -= angle_step
		else:
			angle += angle_step
			
		heading = unit_forward.rotated(unit_up, angle)
		var target:Vector3 = cast_position + heading * avoidance_radius
		if _ray_cast(space_state, target):
			_set_avoidance_heading(heading)
			return
	# If we get here then cannot avoid it but pick biggest angle and random sign
	if LogUtils.debug:
		print_debug("%s-%s: Could not find an ideal avoidance heading, choosing max angle" % [_unit.name, name])
	
	_set_avoidance_heading(heading * MathUtils.randf_sgn())

func _set_avoidance_heading(heading:Vector3) -> void:
	avoidance_heading = heading
	_avoidance_time_rem = avoidance_min_time
	
func _ray_cast(state: PhysicsDirectSpaceState3D, target:Vector3) -> bool:
	_ray_cast_params.to = target
	var result:Dictionary = state.intersect_ray(_ray_cast_params)
	if not result:
		return true
	# Check the navigation obstacle that we hit
	var collider:Node3D = result["collider"] as Node3D
	if not collider:
		return true
	var nav_obstacle:DynamicNavObstacle = DynamicNavObstacle.get_component(collider, false)
	if not nav_obstacle:
		return true
	return not nav_obstacle.affects(_unit)
