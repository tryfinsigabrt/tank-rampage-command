extends Node

const default_collision_margin: float = 0.001

class Layers:
	const world_static: int = 1
	const terrain:int = 1 << 1
	const unit:int = 1 << 2
	const world_dynamic: int = 1 << 3
	const world_boundary: int = 1 << 4
	
	# This is the world bottom
	@warning_ignore("shadowed_global_identifier")
	const floor:int = 1 << 5
	
	const team_1:int = 1 << 28
	const team_2:int = 1 << 29
	# Reserving 30 and 31 if we have 4 total teams
	
	const team_masks:Dictionary[int,int] = {
		1 : Layers.team_1,
		2 : Layers.team_2,
	}
		
class CompositeMasks:
	const all: int = 0xFFFFFFFF
	const world:int = Layers.world_static | Layers.terrain | Layers.world_dynamic
	const visibility: int = world | Layers.unit
	const ground: int = Layers.world_static | Layers.terrain
	
	const all_teams:int = Layers.team_1 | Layers.team_2
	
func enemy_team_mask(team:int) -> int:
	var team_mask:int = Layers.team_masks.get(team, 0)
	if team_mask == 0:
		push_warning("Collisions: Invalid team=%d" % team)
	return CompositeMasks.all_teams ^ team_mask
	
func add_exception_for_layer_and_group(in_body: Node, layer:int, group:StringName) -> void:
	in_body.collision_mask &= ~layer
	# Layers and masks could still match on the other side so add instance exception with bodies in group node
	for unit in get_tree().get_nodes_in_group(group):
		# Add exception for all rigid bodies
		var nodes:Array[Node] = []
		nodes.push_back(unit)
		while not nodes.is_empty():
			var node:Node = nodes.pop_back()
			var rigid_body_node:RigidBody2D = node as RigidBody2D
			if rigid_body_node:
				rigid_body_node.add_collision_exception_with(in_body)
			nodes.append_array(node.get_children())

func apply_team_collision_layer(root: Node, team: int, recursive:bool = true) -> void:
	if not is_instance_valid(root):
		return
		
	var team_mask:int = Layers.team_masks.get(team, -1)
	if team_mask < 0:
		push_warning("Collisions: Invalid team=%d; root=%s" % [team, StringUtils.safe_name(root)])
		return
	
	var nodes:Array[Node] = [root]
	while nodes:
		var node: Node = nodes.pop_back()
		if node is PhysicsBody3D:
			node.collision_layer = MathUtils.update_mask(node.collision_layer, CompositeMasks.all_teams, team_mask)
			if not recursive:
				return
		for child in node.get_children():
			nodes.push_back(child)

func get_aabb_from_collision(collision:Node) -> AABB:
	var collision_shape:CollisionShape3D = collision as CollisionShape3D
	var bounds:AABB
	
	if collision_shape and collision_shape.shape:
		var shape:Shape3D = collision_shape.shape
		if shape is BoxShape3D:
			bounds = bounds.expand(shape.size)
			bounds = bounds.expand(-shape.size)
		elif shape is SphereShape3D:
			bounds = bounds.expand(shape.radius)
			bounds = bounds.expand(-shape.radius)
		elif shape is CapsuleShape3D:
			var extent:Vector3 = Vector3(shape.radius, shape.height, shape.radius) * 0.5
			bounds = bounds.expand(extent)
			bounds = bounds.expand(-extent)
		else:
			push_warning("%s: Unsupported shape %s" % [name, collision_shape])
		bounds = collision_shape.transform * bounds
		
	elif not collision_shape:
		var collision_poly:CollisionPolygon3D = collision as CollisionPolygon3D
		if collision_poly:
			var points:PackedVector2Array = collision_poly.polygon
			for point in points:
				var point_3d:Vector3 = Vector3(point.x, collision_poly.depth, point.y)
				bounds = bounds.expand(point_3d)
			bounds = collision_poly.transform * bounds
	return bounds
