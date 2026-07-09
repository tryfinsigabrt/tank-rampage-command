@tool
class_name ScrapField extends Path3D

# By default extrudes along the z axis so need to rotate so points extrude along the y axis (xz plane)
const PATH_ROTATION_DEG:Vector3 = Vector3(90.0, 0.0, 0.0)
const SHADER_POINT_COUNT:int = 8

@onready var trigger_collision: CollisionPolygon3D = %TriggerCollision
@onready var mesh: MeshInstance3D = %Mesh
@onready var mining_timers: Node = %MiningTimers
@onready var fade_mask_viewport: SubViewport = %FadeMaskViewport
@onready var fade_mask_rect: ColorRect = %FadeMaskRect

## How far additionally to extend the path above and below the path points
@export_range(0.0, 1e9, 0.1, "or_greater")
var path_depth:float = 20.0

@export_range(0.0, 10.0, 0.01, "or_greater")
var visual_y_offset:float = 0.05

@export_range(1, 1e9, 1, "or_greater")
var total_scrap:int = 10000

@export_range(1.0, 1e9, 0.1, "or_greater")
var scrap_mining_interval:float = 5.0

@export_range(1, 1e9, 1, "or_greater")
var scrap_per_interval:int = 50

@export_range(0.1, 40, 0.1, "or_greater")
var randomize_radius_x:float = 20.0

@export_range(0.1, 40, 0.1, "or_greater")
var randomize_radius_z:float = 10.0

@export_range(0.0, 1.0, 0.01)
var randomize_jitter:float = 0.70

@export_tool_button("Randomize") var randomize_shape_button = _randomize_shape

var remaining_scrap:int
var _mining_timers_by_command_center:Dictionary[int,Timer]
var _aabb:AABB


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_refresh_geometry")

var active:bool:
	get:
		return remaining_scrap > 0
	
var open:bool:
	get: return active and _mining_timers_by_command_center.is_empty()
	
var remaining_fraction:float:
	get:
		return float(remaining_scrap) / total_scrap


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


func get_estimated_time_to_exhaustion() -> float:
	if not active:
		return 0.0
	
	var miners:int = _mining_timers_by_command_center.size()
	if not miners:
		return INF
		
	var remaining_intervals:int = ceili(float(remaining_scrap) / (miners * scrap_per_interval))
	return remaining_intervals * scrap_mining_interval 


func _ready() -> void:
	_ensure_instance_local_materials()
	_refresh_geometry()
	_update_visual_state()
	if Engine.is_editor_hint():
		call_deferred("_refresh_geometry")


func _ensure_instance_local_materials() -> void:
	if mesh.material_override:
		mesh.material_override = mesh.material_override.duplicate()
	if fade_mask_rect.material:
		fade_mask_rect.material = fade_mask_rect.material.duplicate()


func _randomize_shape() -> void:
	var new_curve := Curve3D.new()

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in SHADER_POINT_COUNT:
		var angle := TAU * float(i) / float(SHADER_POINT_COUNT)
		var jitter_scale := rng.randf_range(1.0 - randomize_jitter, 1.0 + randomize_jitter)
		var x := cos(angle) * randomize_radius_x * jitter_scale
		var z := sin(angle) * randomize_radius_z * jitter_scale
		new_curve.add_point(Vector3(x, 0.0, z))

	new_curve.closed = true
	curve = new_curve
	_refresh_geometry()


func _refresh_geometry() -> void:
	var point_count:int = curve.point_count
	if not point_count or point_count != SHADER_POINT_COUNT:
		push_error("%s: Exactly 8 points must be defined on the curve!" % name)
		trigger_collision.polygon = PackedVector2Array()
		mesh.mesh = null
		return
	
	if remaining_scrap <= 0:
		remaining_scrap = total_scrap
	
	var projected_points:PackedVector2Array
	projected_points.resize(SHADER_POINT_COUNT)
	
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
	var collision_height:float = absf((height_extent.y - height_extent.x) * 0.5) + path_depth
	var visual_pos := Vector3(0.0, center_y + visual_y_offset, 0.0)
	
	trigger_collision.rotation_degrees = PATH_ROTATION_DEG
	trigger_collision.polygon = points
	trigger_collision.position = poly_pos
	trigger_collision.depth = collision_height
	
	mesh.position = visual_pos
	mesh.mesh = _build_visual_mesh(points)

	
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF

	for point in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	var half_extents := Vector2(
		maxf((max_x - min_x) * 0.5, 0.001),
		maxf((max_y - min_y) * 0.5, 0.001)
	)

	var min_height := center_y - path_depth
	var max_height := center_y + path_depth
	_aabb = AABB(
		Vector3(min_x, min_height, min_y),
		Vector3(max_x - min_x, max_height - min_height, max_y - min_y)
	)

	var normalized_points := PackedVector2Array()
	normalized_points.resize(SHADER_POINT_COUNT)
	var min_point := Vector2(min_x, min_y)
	var size := Vector2(maxf(max_x - min_x, 0.001), maxf(max_y - min_y, 0.001))
	for i in SHADER_POINT_COUNT:
		normalized_points[i] = (points[i] - min_point) / size

	var fade_material := fade_mask_rect.material as ShaderMaterial
	if fade_material:
		fade_material.set_shader_parameter("polygon_points", normalized_points)
		fade_material.set_shader_parameter("edge_fade_width", 0.15)

	fade_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var material := mesh.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("field_half_extents", half_extents)
		material.set_shader_parameter("remaining_fraction", remaining_fraction)
		material.set_shader_parameter("fade_mask_texture", fade_mask_viewport.get_texture())


func _update_visual_state() -> void:
	var material := mesh.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("remaining_fraction", remaining_fraction)


func _build_visual_mesh(points: PackedVector2Array) -> ArrayMesh:
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		return null

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for point in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	var size_x := maxf(max_x - min_x, 0.001)
	var size_y := maxf(max_y - min_y, 0.001)
	var inv_size := Vector2(1.0 / size_x, 1.0 / size_y)
	var min_point := Vector2(min_x, min_y)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(indices.size())
	normals.resize(indices.size())
	uvs.resize(indices.size())

	for i in indices.size():
		var point := points[indices[i]]
		vertices[i] = Vector3(point.x, 0.0, point.y)
		normals[i] = Vector3.UP
		uvs[i] = (point - min_point) * inv_size

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _on_trigger_area_body_entered(body: Node3D) -> void:
	var command_center:CommandCenter = body as CommandCenter
	if not command_center:
		return
	
	print_debug("%s: Command Center: %s entered scrap field" % [name, command_center.name])
	
	if active:
		_register_timer_for(command_center)

#
func _on_trigger_area_body_exited(body: Node3D) -> void:
	var command_center:CommandCenter = body as CommandCenter
	if not command_center:
		return
	
	print_debug("%s: Command Center: %s left scrap field" % [name, command_center.name])
	
	_deregister_timer_for(command_center.get_instance_id())


func _register_timer_for(command_center:CommandCenter) -> void:
	var id:int = command_center.get_instance_id()
	
	if id in _mining_timers_by_command_center:
		push_warning("%s: Timer already registered for %s" % [name, command_center.name])
		return
	
	var mining_component:MiningComponent = MiningComponent.get_component(command_center)
	if mining_component:
		mining_component.add_field(self)
		
	var timer:Timer = Timer.new()
	timer.name = "%d-%s-MiningTimer" % [command_center.team, command_center.name]
	# TODO: If support upgrades then the base interval adjusted by the mining rate upgrade
	timer.wait_time = scrap_mining_interval
	timer.autostart = true
	timer.timeout.connect(_on_mining_timer_timeout.bind(id))
	
	mining_timers.add_child(timer)
	_mining_timers_by_command_center[id] = timer


func _deregister_timer_for(command_center_id:int) -> void:
	var timer:Timer = _mining_timers_by_command_center.get(command_center_id)
	if not timer:
		return
		
	timer.queue_free()
	
	_mining_timers_by_command_center.erase(command_center_id)
	
	var command_center:CommandCenter = instance_from_id(command_center_id)
	if command_center:
		var mining_component:MiningComponent = MiningComponent.get_component(command_center)
		if mining_component:
			mining_component.remove_field(self)


func _remove_all_timers() -> void:
	for command_center_id:int in _mining_timers_by_command_center.keys():
		_deregister_timer_for(command_center_id)


func _on_mining_timer_timeout(command_center_id:int) -> void:
	var command_center:CommandCenter = instance_from_id(command_center_id) as CommandCenter
	if not command_center:
		_deregister_timer_for(command_center_id)
		return
	# Command center must be fully built
	var manufacturing_component:ManufacturingComponent = ManufacturingComponent.get_component(command_center)
	if not manufacturing_component.active:
		return
		
	# TODO: Adjust the base mining interval and/or scrap amount if support command center upgrades
	var mined_scrap:int = mini(scrap_per_interval, remaining_scrap)
	if mined_scrap > 0:
		print_debug("%s: command_center=%s mined %d scrap" % [name, command_center.name, mined_scrap])
		SignalBus.on_scrap_field_mined.emit(self, command_center, mined_scrap)
		remaining_scrap -= mined_scrap
		_update_visual_state()
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
	mesh.visible = false
	_update_visual_state()
	_remove_all_timers()
