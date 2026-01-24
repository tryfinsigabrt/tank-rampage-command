class_name Groups

@warning_ignore("shadowed_global_identifier")
const Unit:StringName = &"Unit"

static func get_parent_in_group(node: Node, group: StringName) -> Node:
	if node.is_in_group(group):
		return node
	if node.get_parent() == null:
		return null
	return get_parent_in_group(node.get_parent(), group)
	
static func get_child_in_group(node: Node, group: StringName) -> Node:
	var stack:Array[Node] = [node]
	for child in node.get_children():
		var next:Node = stack.pop_back()
		if next.is_in_group(group):
			return next
		stack.push_back(child)
	return null
