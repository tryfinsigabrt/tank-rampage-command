class_name Weapon extends Node3D

@onready var cooldown_timer: Timer = $CooldownTimer
@onready var impact_timer: Timer = $ImpactTimer

@export
var speed_range:Vector2 = Vector2(1500,2000)

@export
var max_distance_range:Vector2 = Vector2(500,750)

@export
var cooldown_time_range:Vector2 = Vector2(1.5,2.0)

@export
var enable_debug_draw:bool = true

func fire() -> void:
	if not cooldown_timer.is_stopped():
		await cooldown_timer.timeout
	
	var cooldown:float = _randv(cooldown_time_range)
	_set_timer(cooldown_timer, cooldown)
	
	_hit_scan()
	

var global_forward:Vector3:
	get: return global_transform.basis.z
	
func _hit_scan() -> void:
	# Use physics server rather than ray 3D
	var speed:float = _randv(speed_range)
	var cast_distance:float = _randv(max_distance_range)
	
	#fire_ray.target_position.z = cast_distance
	var space := get_world_3d().direct_space_state
	
	var origin:Vector3 = global_position
	var target:Vector3 = origin + global_forward * cast_distance
	# TODO: Collision mask
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := space.intersect_ray(query)
	var hit_or_end:Vector3
	var is_hit:bool = false
	
	if result:
		var collider: Node3D = result["collider"] as Node3D
		var hit_position: Vector3 = result["position"]
		hit_or_end = hit_position
		var normal: Vector3 = result["normal"]
		is_hit = collider != null
		print_debug("%s: Hit %s at %s with normal=%s" % [name, collider, hit_position, normal])
	else:
		hit_or_end = target
		print_debug("%s: No hit from %s -> %s" % [name, origin, target])
		
	var delta_position:Vector3 = hit_or_end - origin
	var dist:float = delta_position.length()
	var flight_time:float = dist / speed
	if flight_time > 0:
		_set_timer(impact_timer, flight_time)
		await impact_timer.timeout
	
	_draw_debug(origin, hit_or_end, is_hit)
	
func _draw_debug(start: Vector3, end: Vector3, success:bool) -> void:
	if not enable_debug_draw or not OS.is_debug_build():
		return
	DebugDraw3D.draw_arrow(start, end, Color.GREEN if success else Color.RED, 0.1, false, 3.0)

func _randv(min_max: Vector2) -> float:
	return randf_range(min_max.x, min_max.y)
	
func _set_timer(timer:Timer, time: float) -> void:
	timer.wait_time = time
	timer.start()
	
