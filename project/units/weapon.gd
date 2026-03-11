class_name Weapon extends Node3D

@onready var cooldown_timer: Timer = $CooldownTimer
@onready var impact_timer: Timer = $ImpactTimer
@onready var fire_emitter: CPUParticles3D = $FireEmitter
@onready var hit_emitter: CPUParticles3D = $HitEmitter
@onready var damage_emitter: DamageEmitter = $DamageEmitter

@export
var min_distance:float = 10.0

@export
var max_distance_range:Vector2 = Vector2(500,750)

@export
var cooldown_time_range:Vector2 = Vector2(1.5,2.0)

@export
var fire_time_range:Vector2 = Vector2(0.05,0.1)

@export
var damage_v_distance:Curve

@export
var accuracy_v_velocity_alignment:Curve

@export_range(0.0, 90.0, 0.1)
var movement_accuracy_penalty:float

@export_range(0.0, 90.0, 0.1)
var max_spread_angle:float = 22.5

@export
var enable_debug_draw:bool = true

@export_flags_3d_physics
var damage_mask:int = Collisions.CompositeMasks.visibility

@export var allow_source_damage:bool

var _unit:Unit
var _fire_pending:bool

var ideal_fire_range:Vector2:
	get:
		return Vector2(min_distance, max_distance_range.x)

func _ready() -> void:
	_unit = Groups.get_parent_in_group(self, Groups.Unit)
	if not _unit:
		push_error("%s: Weapon not connected to a unit - damage calculations impacted" % name)

func fire() -> void:
	if _fire_pending:
		return
		
	_fire_pending = true
	await _cooldown()
	_fire_pending = false

	fire_emitter.restart()
	
	_set_cooldown()
	
	await _delay_impact()
	_hit_scan()

var global_forward:Vector3:
	get: return global_transform.basis.z
	
func _cooldown() -> void:
	if not cooldown_timer.is_stopped():
		await cooldown_timer.timeout
		
func _set_cooldown() -> void:
	var cooldown:float = _randv(cooldown_time_range)
	_set_timer(cooldown_timer, cooldown)
	
# Delay impact after fire emission before impact to avoid visually inaccurate results
func _delay_impact() -> void:
	var flight_time:float = _randv(fire_time_range)
	_set_timer(impact_timer, flight_time)
	await impact_timer.timeout
		
func _calculate_final_target_deviation_deg(source:Vector3, target:Vector3) -> float:
	var deviation:float = 0.0
	var movement_dir:Vector3 = _unit.velocity.normalized()
	var is_moving:bool = not movement_dir.is_zero_approx()
	if not is_moving:
		return 0.0
		
	if accuracy_v_velocity_alignment:
		var to_target:Vector3 = source.direction_to(target)
		var alignment:float = to_target.dot(movement_dir)
		deviation += 1.0 - accuracy_v_velocity_alignment.sample_baked(alignment)
	var sgn:float = MathUtils.randf_sgn()
	var deviation_deg:float = sgn * minf(deviation * max_spread_angle + movement_accuracy_penalty, max_spread_angle)
	return deviation_deg
	
func _calculate_damage_multiplier(dist:float) -> float:
	if not damage_v_distance:
		return 1.0
	
	var range_fract:float = minf(dist / max_distance_range.y, 1.0)
	var mult:float = damage_v_distance.sample_baked(range_fract)
	return mult
	
func _hit_scan() -> void:
	# Use physics server rather than ray 3D
	var cast_distance:float = _randv(max_distance_range)
		
	var origin:Vector3 = global_position
	var target:Vector3 = origin + global_forward * cast_distance

	var query := PhysicsRayQueryParameters3D.create(origin, target)
	
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = damage_mask
	
	var unit:Unit = Groups.get_parent_in_group(self, Groups.Unit)
	if not allow_source_damage and unit:
		query.exclude = [unit.get_rid()]
	
	var result:Dictionary
	var is_hit:bool = _check_hit(query, result)
	var hit_or_end:Vector3 = result["hit_or_end"]
	
	_draw_debug(origin, hit_or_end, is_hit)
	
	if not is_hit:
		return
		
	# Apply accuracy and damage modifiers
	var hit_position: Vector3 = result["position"]
	var target_dev_deg:float = _calculate_final_target_deviation_deg(origin, hit_position)
	
	if not is_zero_approx(target_dev_deg):
		# Need a new scan for the final target
		var to_target:Vector3 = origin.direction_to(target)
		var dev_to_target:Vector3 = to_target.rotated(global_basis.y, deg_to_rad(target_dev_deg))
		var new_target:Vector3 = origin + dev_to_target * cast_distance
		
		query.to = new_target
		is_hit = _check_hit(query, result)
		if not is_hit:
			return
		
	var damage_params := DamageParameters.from_ray_intersect(result)
	if not damage_params:
		return
		
	var dist:float = origin.distance_to(hit_position)
	damage_params.damage_multiplier = _calculate_damage_multiplier(dist)
	damage_params.source_weapon = self
	damage_params.source_damage_allowed = allow_source_damage
	damage_params.source_unit = unit
	damage_emitter.damage(damage_params)
	
	hit_emitter.global_position = hit_or_end
	hit_emitter.restart()

func _check_hit(query: PhysicsRayQueryParameters3D, out_result:Dictionary) -> bool:
	var space := get_world_3d().direct_space_state
	var result := space.intersect_ray(query)
	var hit_or_end:Vector3
	var is_hit:bool = false
	
	if result:
		var collider: Node3D = result["collider"] as Node3D
		var hit_position: Vector3 = result["position"]
		hit_or_end = hit_position
		var normal: Vector3 = result["normal"]
		is_hit = collider != null
		
		if LogUtils.verbose:
			print_debug("%s: Hit %s at %s with normal=%s" % [name, collider, hit_position, normal])
	else:
		hit_or_end = query.to
		
		if LogUtils.verbose:
			print_debug("%s: No hit from %s -> %s" % [name, query.from, query.to])

	out_result.assign(result)
	out_result["hit_or_end"] = hit_or_end
	
	return is_hit
		
func _draw_debug(start: Vector3, end: Vector3, success:bool) -> void:
	if not enable_debug_draw or not OS.is_debug_build():
		return
	DebugDraw3D.draw_arrow(start, end, Color.GREEN if success else Color.RED, 0.1, false, 3.0)

func _randv(min_max: Vector2) -> float:
	return randf_range(min_max.x, min_max.y)
	
func _set_timer(timer:Timer, time: float) -> void:
	timer.wait_time = time
	timer.start()
	
