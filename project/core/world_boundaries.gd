class_name WorldBoundaries extends Area3D

var _exited_bodies:Dictionary[int,bool] = {}

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
