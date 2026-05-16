class_name ScrapField extends Path3D

# By default extrudes along the z axis so need to rotate so points extrude along the y axis (xz plane)
const PATH_ROTATION_DEG:Vector3 = Vector3(90.0, 0.0, 0.0)

@onready var trigger_collision: CollisionPolygon3D = %TriggerCollision
@onready var trigger_visual: CSGPolygon3D = %TriggerVisual
@onready var mining_timers: Node = %MiningTimers

## How far additionally to extend the path above and below the path points
@export_range(0.0, 1e9, 0.1, "or_greater")
var path_depth:float = 20.0

@export_range(1, 1e9, 1, "or_greater")
var total_scrap:int = 10000

@export_range(1.0, 1e9, 0.1, "or_greater")
var scrap_mining_interval:float = 5.0

@export_range(1, 1e9, 1, "or_greater")
var scrap_per_interval:int = 50

var remaining_scrap:int
var _mining_timers_by_command_center:Dictionary[int,Timer]
var _aabb:AABB

# TODO: Should have a bounds component for these things
## Gets an AABB representing the bounds of the node in local space
func get_bounds() -> AABB:
	return _aabb

## Gets the AABB representing the bounds of the node in global space
func get_global_bounds() -> AABB:
	return global_transform * _aabb
	
func get_mining_teams() -> PackedInt32Array:
	var teams:PackedInt32Array
	for command_center_id in _mining_timers_by_command_center:
		var command_center:CommandCenter = instance_from_id(command_center_id) as CommandCenter
		if command_center and command_center.team not in teams:
			teams.push_back(command_center.team)
	return teams
	
func _ready() -> void:
	var point_count:int = curve.point_count
	if not point_count:
		push_error("%s: No path points defined!" % name)
		return
	
	remaining_scrap = total_scrap
	
	var projected_points:PackedVector2Array
	projected_points.resize(point_count)
	
	var height_extent:Vector2 = Vector2(INF, -INF)
	
	for i in point_count:
		var point:Vector3 = curve.get_point_position(i)
		var point_2d:Vector2 = Vector2(point.x, point.z)
		
		height_extent.x = minf(height_extent.x, point.y)
		height_extent.y = maxf(height_extent.y, point.y)
		
		projected_points[i] = point_2d
		
	_update_polygons.call_deferred(projected_points, height_extent)
	
func _update_polygons(points: PackedVector2Array, height_extent:Vector2) -> void:
	# Center the collision on path center
	var center_y: float = (height_extent.x + height_extent.y) * 0.5
	var poly_pos:Vector3 = Vector3(0.0, center_y, 0.0)
	var height:float = absf((height_extent.y - height_extent.x) * 0.5) + path_depth
	
	trigger_collision.rotation_degrees = PATH_ROTATION_DEG
	trigger_collision.polygon = points
	trigger_collision.position = poly_pos
	trigger_collision.depth = height
	
	trigger_visual.rotation_degrees = PATH_ROTATION_DEG
	trigger_visual.polygon = points
	trigger_visual.position = poly_pos
	trigger_visual.depth = height
	
	_aabb = Collisions.get_aabb_from_colision_polygon(trigger_collision)
	
func _on_trigger_area_body_entered(body: Node3D) -> void:
	var command_center:CommandCenter = body as CommandCenter
	if not command_center:
		return
	
	print_debug("%s: Command Center: %s entered scrap field" % [name, command_center.name])
	
	if remaining_scrap > 0:
		_register_timer_for(command_center)

func _on_trigger_area_body_exited(body: Node3D) -> void:
	var command_center:CommandCenter = body as CommandCenter
	if not command_center:
		return
	
	print_debug("%s: Command Center: %s left scrap field" % [name, command_center.name])
	
	_deregister_timer_for(command_center.get_instance_id())
		
func _register_timer_for(command_center:CommandCenter) -> void:
	var id:int = command_center.get_instance_id()
	
	var timer:Timer = Timer.new()
	timer.name = "%d-%s-MiningTimer" % [command_center.team, command_center.name]
	# TODO: If support upgrades then the base interval adjusted by the mining rate upgrade
	timer.wait_time = scrap_mining_interval
	timer.autostart = true
	timer.timeout.connect(_on_mining_timer_timeout.bind(id))
	
	mining_timers.add_child(timer)
	
func _deregister_timer_for(command_center_id:int) -> void:
	var timer:Timer = _mining_timers_by_command_center.get(command_center_id)
	if not timer:
		return
		
	timer.queue_free()
	_mining_timers_by_command_center.erase(command_center_id)
	
func _remove_all_timers() -> void:
	for timer:Timer in _mining_timers_by_command_center.values():
		timer.queue_free()
		
	_mining_timers_by_command_center.clear()
	
func _on_mining_timer_timeout(command_center_id:int) -> void:
	var command_center:CommandCenter = instance_from_id(command_center_id) as CommandCenter
	if not command_center:
		_deregister_timer_for(command_center_id)
		return
		
	# TODO: Adjust the base mining interval and/or scrap amount if support command center upgrades
	var mined_scrap:int = mini(scrap_per_interval, remaining_scrap)
	if mined_scrap > 0:
		print_debug("%s: command_center=%s mined %d scrap" % [name, command_center.name, mined_scrap])
		SignalBus.on_scrap_field_mined.emit(self, command_center, mined_scrap)
		remaining_scrap -= mined_scrap
	else:
		print("%s: Resource field exhausted!" % name)
		_resources_exhausted()

func _resources_exhausted() -> void:
	for command_center_id in _mining_timers_by_command_center:
		var command_center:CommandCenter = instance_from_id(command_center_id) as CommandCenter
		if command_center:
			SignalBus.on_scrap_field_mined.emit(self, command_center)
			
	# Also disable the area
	trigger_collision.disabled = true
	trigger_visual.visible = false
	
	_remove_all_timers()
