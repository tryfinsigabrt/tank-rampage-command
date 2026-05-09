class_name WorldBoundaries extends Area3D

const MAX_POINT_INTERSECT_RESULTS:int = 256

# TODO: Keeping objects corralled will be much easier if entering the area means out of bounds instead of leaving
# since then the edge of the object will trigger it rather than the whole object leaving. 
# So all these events would be inverted
# Can use a series of planes for the boundary
# Maybe we can leverage https://docs.godotengine.org/en/stable/classes/class_worldboundaryshape3d.html

var _exited_bodies:Dictionary[int,bool] = {}

var _bounds:AABB

var bounds:AABB:
	get:
		return _bounds
		
func _ready() -> void:
	_bounds = Collisions.calculate_aabb(self)
	_bounds = transform * _bounds
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

func contains_body(body: Node3D) -> bool:
	var aabb:AABB = body.get_global_bounds() if body.has_method("get_global_bounds") else Collisions.calculate_aabb(body)
	if not aabb.has_volume():
		push_warning("%s: Unable to determine AABB from body=%s - defaulting to global position point check" % [name, body.name])
		return contains_point(body.global_position)
	
	# Use a plane through the center of the AABB
	#var center:Vector3 = aabb.get_center()
	#var box_planar_half_size:Vector3 = aabb.size * 0.5
	#
	#var planar_points:PackedVector3Array = [
		#center + Vector3(-box_planar_half_size.x, 0.0, box_planar_half_size.z),
		#center + Vector3(-box_planar_half_size.x, 0.0, -box_planar_half_size.z),
		#center + Vector3(box_planar_half_size.x, 0.0, box_planar_half_size.z),
		#center + Vector3(box_planar_half_size.x, 0.0, -box_planar_half_size.z)
	#]
	
	# Use the bottom points
	var planar_points:PackedVector3Array = [	
		aabb.get_endpoint(Collisions.AABBCorner.FRONT_BOTTOM_LEFT),
		aabb.get_endpoint(Collisions.AABBCorner.FRONT_BOTTOM_RIGHT),
		aabb.get_endpoint(Collisions.AABBCorner.BACK_BOTTOM_LEFT),
		aabb.get_endpoint(Collisions.AABBCorner.BACK_BOTTOM_RIGHT)
	]
	
	for point in planar_points:
		if not contains_point(point):
			return false
			
	return true

func contains_point(point:Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state

	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = collision_layer

	# perform the query
	var results := space_state.intersect_point(query, MAX_POINT_INTERSECT_RESULTS)

	for r in results:
		if r.collider == self:
			return true

	return false
