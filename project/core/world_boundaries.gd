class_name WorldBoundaries extends Area3D

var _exited_bodies:Dictionary[int,bool] = {}

var _bounds:AABB

var bounds:AABB:
	get:
		return _bounds
		
func _ready() -> void:
	for child in get_children():
		var collision_shape:CollisionShape3D = child as CollisionShape3D
		if collision_shape and collision_shape.shape:
			var center:Vector3 = collision_shape.global_position
			var shape:Shape3D = collision_shape.shape
			if shape is BoxShape3D:
				_bounds = _bounds.expand(center + shape.size)
				_bounds = _bounds.expand(center - shape.size)
			elif shape is SphereShape3D:
				_bounds = _bounds.expand(center + shape.radius)
				_bounds = _bounds.expand(center - shape.radius)
			else:
				push_warning("%s: Unsupported shape %s" % [name, collision_shape])
		elif not collision_shape:
			var collision_poly:CollisionPolygon3D = child as CollisionPolygon3D
			if collision_poly:
				var center:Vector3 = collision_poly.global_position
				var points:PackedVector2Array = collision_poly.polygon
				for point in points:
					var point_3d:Vector3 = Vector3(point.x, collision_poly.depth, point.y)
					_bounds = _bounds.expand(center + point_3d)
					
	# Convert bounds to world space
	print_debug("%s: World boundaries AABB=%s" % [name, _bounds])
				
func _on_body_entered(body: Node3D) -> void:
	print_debug("%s: body entered: %s" % [name, body])
	if not body.has_signal(&"on_entered_world_boundaries"):
		return
		
	var id:int = body.get_instance_id()
	if _exited_bodies.erase(id):
		body.on_entered_world_boundaries.emit(self)


func _on_body_exited(body: Node3D) -> void:
	print_debug("%s: body exited: %s" % [name, body])
	if not body.has_signal(&"on_left_world_boundaries"):
		return
	var id:int = body.get_instance_id()
	if not id in _exited_bodies:
		_exited_bodies[id] = true
		body.on_left_world_boundaries.emit(self)

func contains_point(point:Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state

	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = collision_layer

	# perform the query
	var results := space_state.intersect_point(query)

	for r in results:
		if r.collider == self:
			return true

	return false
