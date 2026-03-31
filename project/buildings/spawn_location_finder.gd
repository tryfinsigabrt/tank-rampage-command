class_name SpawnLocationFinder extends Node3D

var _shape_rid:RID

@export
var bounds:Vector2 = Vector2.ONE * 100.0

@export
var bounds_dir:Vector2 = Vector2.UP

@export
var y_extent:float = 500.0

@export_range(0.0, 1e9, 0.01, "or_greater")
var extent_safety_factor:float = 0.1

@export_flags_3d_physics
var collision_mask:int = Collisions.CompositeMasks.any_asset

func _enter_tree() -> void:
	if not _shape_rid:
		_shape_rid = PhysicsServer3D.box_shape_create()
	
func _exit_tree() -> void:
	if _shape_rid:
		PhysicsServer3D.free_rid(_shape_rid)

## Returns a viable spawn grid location
func find_viable_spawn_grid_location(in_pos:Vector3, spawned:Unit) -> Vector3:
	var occupied_bounds: Array[Rect2] = sweep_grid_bounds(in_pos)
	if not occupied_bounds:
		return in_pos
	
	var pos:Vector2 = Vector2(in_pos.x, in_pos.z)
	var unit_bounds_rect:Rect2 = Bounds.aabb_to_grid_rect(_get_aabb(spawned))
	var unit_extents:Vector2 = unit_bounds_rect.size
	
	var count:int = mini(floori(bounds.x / unit_extents.x), floori(bounds.y / unit_extents.y))
	
	var dir_norm:Vector2 = bounds_dir.normalized()
	var forward_angle:float = dir_norm.angle()
	var min_angle:float = forward_angle - PI * 0.5
	var unit_extent:float = unit_extents.length() * (1.0 + extent_safety_factor)
	
	# Perpendicular chord of circle bisector - half chord length and half angle forms right triangle
	# d is the unit bounds extent and r is how far out in increments of unit_extent
	# theta = 2 * asin(d * 0.5 / r)
	# But we want to go above and below so use theta/2
	var half_extent:float = unit_extent * 2.0
	
	for i in range(1, count + 1):
		var radius: float = unit_extent * (i + 1)
		var delta_angle:float = asin(half_extent / radius)
		var increments:int = floori(PI / delta_angle)
		var angle:float = min_angle
		for j in increments:
			var test_pos:Vector2 = pos + Vector2.from_angle(angle) * radius
			var test_bounds:Rect2 = Rect2(test_pos, unit_extents)
			var open:bool = true
			for bound in occupied_bounds:
				if bound.intersects(test_bounds):
					open = false
					break
			if open:
				return Vector3(test_pos.x, in_pos.y, test_pos.y)
			angle += delta_angle	
	return Vector3.INF

func sweep_grid_bounds(pos: Vector3) -> Array[Rect2]:
	var half_extent:Vector2 = bounds * 0.5
	
	PhysicsServer3D.shape_set_data(_shape_rid, Vector3(half_extent.x, y_extent, half_extent.y))

	var bounds_offset:Vector2 = bounds_dir * half_extent
	var box_center:Vector3 = pos + Vector3(bounds_offset.x, 0.0, bounds_offset.y)
	
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = collision_mask
	params.margin = Collisions.default_collision_margin
	params.transform = Transform3D(Basis.IDENTITY, box_center)
	params.shape_rid = _shape_rid
	
	var space_state := get_viewport().world_3d.direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(params)
	
	var occupied_bounds:Array[Rect2]
	
	for result in results:
		var asset:Node3D = result.get("collider") as Node3D
		if not asset:
			continue
			
		var aabb:AABB = _get_aabb(asset)
		occupied_bounds.push_back(Bounds.aabb_to_grid_rect(aabb))
	
	print_debug("%s: sweep_grid_bounds(%s) -> %s" % [name, pos, occupied_bounds])		
	return occupied_bounds

static func _get_aabb(asset: Node3D) -> AABB:
	var aabb:AABB
	if asset.has_method("get_bounds"):
		aabb = asset.get_bounds()
	else:
		aabb = Collisions.calculate_aabb(asset)
		
	return asset.global_transform * aabb
