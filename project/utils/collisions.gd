extends Node

const default_collision_margin: float = 0.001
const weapon_sweep_result_count:int = 256

class Layers:
	const world_static: int = 1
	const terrain:int = 1 << 1
	const unit:int = 1 << 2
	const world_dynamic: int = 1 << 3
	
	# This is the world bottom
	@warning_ignore("shadowed_global_identifier")
	const floor:int = 1 << 5
	
class CompositeMasks:
	const all: int = 0xFFFFFFFF
	const world:int = Layers.world_static | Layers.terrain | Layers.world_dynamic
	const visibility: int = world | Layers.unit

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
