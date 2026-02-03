class_name Groups

@warning_ignore("shadowed_global_identifier")
const Unit:StringName = &"Unit"

@warning_ignore("shadowed_global_identifier")
const UnitActions:StringName = &"UnitActions"

const Damageable:StringName = &"Damageable"

class Units:
	const Tank:StringName = &"UnitClassTank"
	const Artillery:StringName = &"UnitClassArtillery"
	const Soldier:StringName = &"UnitClassSoldier"
		
static func get_parent_in_group(node: Node, group: StringName) -> Node:
	if node.is_in_group(group):
		return node
	if node.get_parent() == null:
		return null
	return get_parent_in_group(node.get_parent(), group)
	
static func get_children_in_group(root: Node, group: StringName, return_on_first:bool=false) -> Array[Node]:
	var stack:Array[Node] = [root]
	var group_nodes:Array[Node] = []
	
	while not stack.is_empty():
		var node:Node = stack.pop_back()
		if node.is_in_group(group):
			group_nodes.push_back(node)
			if return_on_first:
				return group_nodes
		stack.append_array(node.get_children())
	return group_nodes
