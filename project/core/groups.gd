class_name Groups

@warning_ignore_start("shadowed_global_identifier")

const Unit:StringName = &"Unit"
const MatchTeam:StringName = &"MatchTeam"
const Match:StringName = &"Match"

const Player:StringName = &"Player"

const UnitActions:StringName = &"UnitActions"

const Damageable:StringName = &"Damageable"

@warning_ignore_restore("shadowed_global_identifier")

class Units:
	const Tank:StringName = &"UnitClassTank"
	const Artillery:StringName = &"UnitClassArtillery"
	const Soldier:StringName = &"UnitClassSoldier"
		
static func get_parent_in_group(leaf: Node, group: StringName) -> Node:
	return get_parent_matching(leaf, func(node): return node.is_in_group(group) )
	
static func get_parent_with_type(leaf: Node, type) -> Node:
	return get_parent_matching(leaf, func(node): return is_instance_of(node, type) )

static func has_ancestor(leaf: Node, ancestor: Node) -> bool:
	return get_parent_matching(leaf, func(node): return node == ancestor) != null
	
static func get_parent_matching(leaf: Node, predicate:Callable) -> Node:
	var node:Node = leaf
	while node:
		if predicate.call(node):
			return node
		node = node.get_parent()
	return null
	
static func get_children_in_group(root: Node, group: StringName, return_on_first:bool=false) -> Array[Node]:
	return get_children_matching(root, func(node): return node.is_in_group(group), return_on_first)
	
static func get_children_with_type(root: Node, type, return_on_first:bool=false) -> Array[Node]:
	return get_children_matching(root, func(node): return is_instance_of(node, type), return_on_first)

static func is_child_in_tree(root:Node, child:Node) -> bool:
	return not get_children_matching(root, func(node): return node == child, true).is_empty()
	
static func get_children_matching(root: Node, predicate: Callable, return_on_first:bool=false) -> Array[Node]:
	var stack:Array[Node] = [root]
	var matching_nodes:Array[Node] = []
	
	while not stack.is_empty():
		var node:Node = stack.pop_back()
		if predicate.call(node):
			matching_nodes.push_back(node)
			if return_on_first:
				return matching_nodes
		stack.append_array(node.get_children())
	return matching_nodes
