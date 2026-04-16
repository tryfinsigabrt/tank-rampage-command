class_name ScrapField extends Path3D

# By default extrudes along the z axis so need to rotate so points extrude along the y axis (xz plane)
const PATH_ROTATION_DEG:Vector3 = Vector3(90.0, 0.0, 0.0)

@onready var trigger_collision: CollisionPolygon3D = %TriggerCollision
@onready var trigger_visual: CSGPolygon3D = %TriggerVisual
@onready var mining_timer: Timer = %MiningTimer

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
var _command_center_ids:PackedInt64Array

func _ready() -> void:
	var point_count:int = curve.point_count
	if not point_count:
		push_error("%s: No path points defined!" % name)
		return
	
	mining_timer.wait_time = scrap_mining_interval
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
	
func _on_trigger_area_body_entered(body: Node3D) -> void:
	var command_center:CommandCenter = body as CommandCenter
	if not command_center:
		return
	
	print_debug("%s: Command Center: %s entered scrap field" % [name, command_center.name])
	_command_center_ids.push_back(command_center.get_instance_id())
	
	# Start timer if it isn't already running and there is scrap left
	if mining_timer.is_stopped() and remaining_scrap > 0:
		mining_timer.start()
		

func _on_trigger_area_body_exited(body: Node3D) -> void:
	var command_center:CommandCenter = body as CommandCenter
	if not command_center:
		return
	
	print_debug("%s: Command Center: %s left scrap field" % [name, command_center.name])
	_command_center_ids.erase(command_center.get_instance_id())
	
	if _command_center_ids.is_empty():
		mining_timer.stop()
		
func _on_mining_timer_timeout() -> void:
	var exhausted:bool = false
	
	var command_centers:Array[CommandCenter]
	var invalid_ids:PackedInt64Array
	
	command_centers.resize(_command_center_ids.size())
	var count:int = 0
	
	for id in _command_center_ids:
		var command_center:CommandCenter = instance_from_id(id) as CommandCenter
		if command_center:
			command_centers[count] = command_center
			count += 1
		else:
			invalid_ids.push_back(id)
	
	if invalid_ids:
		command_centers.resize(count)
		for invalid_id in range(invalid_ids.size() - 1, -1, -1):
			_command_center_ids.erase(invalid_id)
			
	if not command_centers:
		mining_timer.stop()
		return
		
	for command_center in command_centers:
		var mined_scrap:int = mini(scrap_per_interval, remaining_scrap)
		if mined_scrap > 0:
			print_debug("%s: command_center=%s mined %d scrap" % [name, command_center.name, mined_scrap])
			SignalBus.on_scrap_field_mined.emit(self, command_center, mined_scrap)
			remaining_scrap -= mined_scrap
		else:
			print("%s: Resource field exhausted!" % name)
			exhausted = true
			break
	
	if exhausted:
		mining_timer.stop()
		# Also disable the area
		trigger_collision.disabled = true
		trigger_visual.visible = false
		
		for command_center in command_centers:
			SignalBus.on_scrap_field_mined.emit(self, command_center)
