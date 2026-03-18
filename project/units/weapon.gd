class_name Weapon extends Node3D

signal firing_state_changed(firing:bool)

## Type of trace to do when firing
enum TraceType
{
	## Standard hit scan from source to target
	Standard,
	## Drop a vertical ray down to target position
	## Useful for missile drops
	Drop,
	
	## Two phase hit scan useful for artillery shells.
	## First does a hit scan on launch to make sure doesn't hit something in front of target
	## If so, then it explodes in that pass
	## If no hit, then invoke drop behavior.
	Launch
}

@onready var cooldown_timer: Timer = $CooldownTimer
@onready var impact_timer: Timer = $ImpactTimer
@onready var fire_emitter: CPUParticles3D = $FireEmitter
@onready var hit_emitter: CPUParticles3D = $HitEmitter
@onready var damage_emitter: DamageEmitter = $DamageEmitter
@onready var fire_state_timer: Timer = $FireStateTimer

@export
var min_distance:float = 10.0

@export
var max_distance_range:Vector2 = Vector2(500,750)

@export
var cooldown_time_range:Vector2 = Vector2(1.5,2.0)

@export
var fire_time_range:Vector2 = Vector2(0.05,0.1)

@export
var fire_time_v_distance:Curve

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

## Whether the weapon can damage allies
@export
var friendly_fire:bool = false

@export_flags_3d_physics
var damage_mask:int = Collisions.CompositeMasks.visibility

@export var allow_source_damage:bool

@export var type: TraceType = TraceType.Standard

var _unit:Unit
var _fire_pending:bool
var _mask_requires_refresh:bool

## Target that the weapon is trying to hit
## Not used for Standard fire mode. Used for Drop and launch
var fire_target:Vector3

## Node to use to do the launch trace for launch-based weapons
## Defaults to self if not assigned
@export
var launch_trace_node:Node3D

## Size of the impact probability zone vs fraction of min to max firing distance
@export
var target_dev_v_distance:Curve

var ideal_fire_range:Vector2:
	get:
		return Vector2(min_distance, max_distance_range.x)

func _ready() -> void:
	_unit = Groups.get_parent_in_group(self, Groups.Unit)
	if not _unit:
		push_error("%s: Weapon not connected to a unit - damage calculations impacted" % name)
	
	fire_state_timer.wait_time = cooldown_time_range.y * 2.0
	_mask_requires_refresh = not friendly_fire
	
	if not launch_trace_node:
		launch_trace_node = self 
	
func fire() -> void:
	if _fire_pending:
		return
		
	if fire_state_timer.is_stopped():
		firing_state_changed.emit(true)
	
	# Be sure to always reset the firing state ended timer
	fire_state_timer.start()
		
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

func _refresh_damage_mask() -> void:
	if friendly_fire:
		damage_mask |= Collisions.CompositeMasks.any_unit
	else:
		var enemy_team_mask:int = Collisions.enemy_team_mask(_unit.team)
		damage_mask = MathUtils.update_mask(damage_mask, Collisions.CompositeMasks.any_unit, enemy_team_mask)
		
# Delay impact after fire emission before impact to avoid visually inaccurate results
func _delay_impact() -> void:
	var flight_time:float
	if fire_time_v_distance and type == TraceType.Launch:
		var dist:float = launch_trace_node.global_position.distance_to(fire_target)
		flight_time = fire_time_v_distance.sample_baked(dist)
		# Randomize
		flight_time += MathUtils.randf_range_signed(fire_time_range.x, fire_time_range.y)
	else:
		flight_time = _randv(fire_time_range)
		
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
	if _mask_requires_refresh:
		_refresh_damage_mask()
		
	# Use physics server rather than ray 3D
	var query := _create_trace_query()
	var cast_distance:float = _randv(max_distance_range)
	var result:Dictionary
	
	var is_hit:bool = _weapon_trace(query, result, cast_distance)
	if not is_hit:
		return
		
	if not _apply_accuracy_modifier(query, result, cast_distance):
		return
		
	var damage_params := _create_damage_params(query, result)
	if not damage_params:
		return
		
	damage_emitter.damage(damage_params)
	
	var hit_or_end:Vector3 = result["hit_or_end"]
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

func _is_debug_draw_enabled() -> bool: return enable_debug_draw and OS.is_debug_build()
	
func _draw_debug(start: Vector3, end: Vector3, success:bool) -> void:
	if not _is_debug_draw_enabled():
		return
	DebugDraw3D.draw_arrow(start, end, Color.GREEN if success else Color.RED, 0.1, false, 3.0)

func _randv(min_max: Vector2) -> float:
	return randf_range(min_max.x, min_max.y)
	
func _set_timer(timer:Timer, time: float) -> void:
	timer.wait_time = maxf(0.01, time)
	timer.start()
	
func _on_fire_state_timer_timeout() -> void:
	firing_state_changed.emit(false)
	
#region Trace Helpers

func _apply_accuracy_modifier(query: PhysicsRayQueryParameters3D, result:Dictionary, cast_distance:float) -> bool:
	var origin := query.from
	var target := query.to
	
	var hit_position: Vector3 = result["position"]
	var target_dev_deg:float = _calculate_final_target_deviation_deg(origin, hit_position)
	
	if is_zero_approx(target_dev_deg):
		return true
	
	# Need a new scan for the final target
	var to_target:Vector3 = origin.direction_to(target)
	var dev_to_target:Vector3 = to_target.rotated(global_basis.y, deg_to_rad(target_dev_deg))
	var new_target:Vector3 = origin + dev_to_target * cast_distance
	
	query.to = new_target
	return _check_hit(query, result)
	
func _create_damage_params(query: PhysicsRayQueryParameters3D, result: Dictionary) -> DamageParameters:
	var damage_params := DamageParameters.from_ray_intersect(result)
	if not damage_params:
		return null
		
	var hit_position: Vector3 = result["position"]
	var dist:float = query.from.distance_to(hit_position)
	
	damage_params.damage_mask = damage_mask
	damage_params.damage_multiplier = _calculate_damage_multiplier(dist)
	damage_params.source_weapon = self
	damage_params.source_damage_allowed = allow_source_damage
	damage_params.source_unit = _unit
	
	return damage_params	
	
func _create_trace_query() -> PhysicsRayQueryParameters3D:
	var query := PhysicsRayQueryParameters3D.new()
	
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = damage_mask
	
	if not allow_source_damage and _unit:
		query.exclude = [_unit.get_rid()]
	return query
	
#endregion

#region Trace Types

func _weapon_trace(query: PhysicsRayQueryParameters3D, result:Dictionary, cast_distance:float) -> bool:
	match type:
		TraceType.Standard:
			return _standard_trace(query, result, cast_distance)
		TraceType.Drop:
			return _drop_trace(query, result)
		TraceType.Launch:
			return _launch_trace(query, result)
		_:
			assert(false, "Unsupported trace type=%s" % type)
			result["hit_or_end"] = Vector3.INF
			return false
			
func _standard_trace(query: PhysicsRayQueryParameters3D, result:Dictionary, cast_distance:float) -> bool:
	var origin:Vector3 = global_position
	var target:Vector3 = origin + global_forward * cast_distance

	query.from = origin
	query.to = target
	
	var is_hit := _check_hit(query, result)
	
	if _is_debug_draw_enabled():
		_draw_debug(origin, result["hit_or_end"], is_hit)
	
	return is_hit
	
func _drop_trace(query: PhysicsRayQueryParameters3D, result:Dictionary) -> bool:
	var target:Vector3 = fire_target
	if target_dev_v_distance:
		var origin:Vector3 = global_position
		var dist:float = origin.distance_to(target)
		var distance_fraction:float = clampf(dist / (max_distance_range.y - min_distance), 0.0, 1.0)
		var radius:float = target_dev_v_distance.sample_baked(distance_fraction)
		if radius > 0:
			var offset:Vector2 = MathUtils.get_random_point_in_circle(radius)
			target.x += offset.x
			target.z += offset.y
		
	
	query.from = fire_target + 1000 * Vector3.UP
	query.to = fire_target
	
	var is_hit := _check_hit(query, result)
	
	if _is_debug_draw_enabled():
		_draw_debug(query.from, result["hit_or_end"], is_hit)
	
	return is_hit

func _launch_trace(query: PhysicsRayQueryParameters3D, result:Dictionary) -> bool:
	var target:Vector3 = fire_target
	var origin:Vector3 = launch_trace_node.global_position
	
	var trace_dist:float = 0.5 * origin.distance_to(target)
	var trace_dir:Vector3 = -launch_trace_node.global_transform.basis.z
	
	query.from = origin
	query.to = origin + trace_dir * trace_dist
	var is_hit := _check_hit(query, result)
	
	# Don't fire if going to hit an obstacle on launch
	if is_hit:
		return false
		
	return _drop_trace(query, result)

#endregion
