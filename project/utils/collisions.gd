@tool
extends Node

const default_collision_margin: float = 0.001

class Layers:
	const world_static: int = 1
	const terrain:int = 1 << 1
	const unit:int = 1 << 2
	const world_dynamic: int = 1 << 3
	const world_boundary: int = 1 << 4
	
	## Building like a CommandCenter or Baracks (see also Groups)
	const building:int = 1 << 5
	## A defensive structure that blocks infantry
	const structure_infantry:int = 1 << 6
	
	## A pickup resource like scrap
	const resource:int = 1 << 7
	
	## Mechanized vs non-mechanized units for specific obstacle filtering
	const infantry:int = 1 << 8
	const vehicle:int = 1 << 9
	
	## A structure that blocks behicles
	const structure_vehicle:int = 1 << 10
	
	## A generic boundary like a scrap field
	const boundary:int = 1 << 11
	
	## A control point
	const control_point:int = 1 << 12
	
	## A structure that is an explosive
	## This is currently used for landmines for weapons to target them or for scans to find them
	## But to not block movement of infantry or vehicles
	## They are also typically hidden so shouldn't show up on simpler structure scans
	const structure_explosive:int = 1 << 13
	
	## Layer assigned to assets on team 1
	const team_1:int = 1 << 28
	
	## Layer assigned to assets on team 2
	const team_2:int = 1 << 29
	
	# Reserving 30 and 31 if we have 4 total teams
	
	const team_masks:Dictionary[int,int] = {
		1 : Layers.team_1,
		2 : Layers.team_2,
	}
		
class CompositeMasks:
	const all: int = 0xFFFFFFFF
	const world:int = Layers.world_static | Layers.terrain | Layers.world_dynamic
	const visibility: int = world | team_asset
	const ground: int = Layers.world_static | Layers.terrain
	# Exclude structure_explosive as these are treated specially
	const structure:int = Layers.structure_infantry | Layers.structure_vehicle
	const team_asset:int = Layers.unit | Layers.building | structure
	const damageable_team_asset:int = team_asset
	
	const all_teams:int = Layers.team_1 | Layers.team_2
	const any_unit:int = all_teams | Layers.unit
	const any_asset:int = all_teams | CompositeMasks.team_asset
	
enum AABBCorner {
	# Bottom / Front face (Lower Z)
	FRONT_BOTTOM_LEFT  = 0, # (min, min, min)
	FRONT_BOTTOM_RIGHT = 1, # (max, min, min)
	FRONT_TOP_LEFT     = 2, # (min, max, min)
	FRONT_TOP_RIGHT    = 3, # (max, max, min)
	
	# Top / Back face (Higher Z)
	BACK_BOTTOM_LEFT   = 4, # (min, min, max)
	BACK_BOTTOM_RIGHT  = 5, # (max, min, max)
	BACK_TOP_LEFT      = 6, # (min, max, max)
	BACK_TOP_RIGHT     = 7  # (max, max, max)
}

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

## Applies the team collision mask. If 0 then it clears out the team mask
func apply_team_collision_layer(root: Node, team: int, recursive:bool = true) -> void:
	if not is_instance_valid(root):
		return
		
	var team_mask:int = Layers.team_masks.get(team, -1) if team > 0 else 0
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
		bounds = get_aabb_from_shape(shape)
		bounds = collision_shape.transform * bounds
		
	elif not collision_shape:
		var collision_poly:CollisionPolygon3D = collision as CollisionPolygon3D
		if collision_poly:
			bounds = get_aabb_from_colision_polygon(collision_poly)
	return bounds

func get_aabb_from_shape(shape:Shape3D) -> AABB:
	var bounds:AABB
	if shape is BoxShape3D:
		var half_size:Vector3 = shape.size * 0.5
		bounds = bounds.expand(half_size)
		bounds = bounds.expand(-half_size)
	elif shape is SphereShape3D:
		bounds = bounds.expand(Vector3.ONE * shape.radius)
		bounds = bounds.expand(-Vector3.ONE * shape.radius)
	elif shape is CapsuleShape3D:
		var extent:Vector3 = Vector3(shape.radius, shape.height * 0.5, shape.radius)
		bounds = bounds.expand(extent)
		bounds = bounds.expand(-extent)
	else:
		push_warning("%s: Unsupported shape %s" % [name, shape])
		
	return bounds
	
func get_aabb_from_colision_polygon(collision_poly: CollisionPolygon3D) -> AABB:
	var points:PackedVector2Array = collision_poly.polygon
	var bounds:AABB
	for point in points:
		var point_3d:Vector3 = Vector3(point.x, collision_poly.depth, point.y)
		bounds = bounds.expand(point_3d)
	bounds = collision_poly.transform * bounds
	return bounds
	
## Controls how the calculation is done for AABB
enum AABBCalculationType
{
	## Only use the given input node - must be a CollisionShape3D or CollisionPolygon3D
	SELF,
	
	## Does calculation for all child nodes that are shapes or polygons
	CHILDREN,
	
	## Does calculation for self and all children recursively
	RECURSIVE
}

## Calculates an AABB for given node. behavior is one of AABB_SELF, AABB_CHILDREN, AABB_RECURSIVE
func calculate_aabb(node: Node, type:AABBCalculationType = AABBCalculationType.CHILDREN) -> AABB:
	var bounds:AABB
	if type != AABBCalculationType.CHILDREN and is_supported_collision_type(node):
		bounds = get_aabb_from_collision(node)
	
	if type == AABBCalculationType.SELF:
		return bounds
			
	var nodes:Array[Node] = node.get_children()
	var recursive:bool = type == AABBCalculationType.RECURSIVE
	
	while nodes:
		var child:Node = nodes.pop_back()
		if is_supported_collision_type(child):
			var child_bounds:AABB = get_aabb_from_collision(child)
			if bounds:
				bounds = bounds.merge(child_bounds)
			else:
				bounds = child_bounds
		if recursive:
			nodes.append_array(child.get_children())
	return bounds

func is_supported_collision_type(node: Node) -> bool:
	return node is CollisionShape3D or node is CollisionPolygon3D
	
func get_collisions_nodes(node: Node, type: AABBCalculationType = AABBCalculationType.CHILDREN) -> Array[Node]:
	var matching_nodes:Array[Node]
	if type != AABBCalculationType.CHILDREN and is_supported_collision_type(node):
		matching_nodes.push_back(node)
	
	if type == AABBCalculationType.SELF:
		return matching_nodes
			
	var nodes:Array[Node] = node.get_children()
	var recursive:bool = type == AABBCalculationType.RECURSIVE
	
	while nodes:
		var child:Node = nodes.pop_back()
		if is_supported_collision_type(child):
			matching_nodes.push_back(child)
		if recursive:
			nodes.append_array(child.get_children())
	return matching_nodes
