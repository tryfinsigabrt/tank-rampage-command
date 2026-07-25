class_name SceneUtils

static func instantiate_placeholder(scene:PackedScene, parent:Node, initial_position:Vector3 = Vector3.ZERO) -> Node:
	if not scene or not parent:
		return null
	
	var instance:Node = scene.instantiate()
	if instance is Node3D:
		instance.visible = false
		instance.position = initial_position
		
	parent.add_child(instance)
	disable_all_interactions(instance)
	
	return instance
	
static func disable_all_interactions(node: Node) -> void:
	# Some structures like land mines also have an area node so need to get all children as well
	for static_body:CollisionObject3D in Groups.get_children_with_type(node, CollisionObject3D):
		# This will disable collision
		static_body.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Disable any dynamic obstacles added
	for dynamic_obstacle:Node in Groups.get_children_with_type(node, DynamicNavObstacle):
		dynamic_obstacle.queue_free()
