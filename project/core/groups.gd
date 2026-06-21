class_name Groups

@warning_ignore_start("shadowed_global_identifier")

const Interactable:StringName = &"Interactable"
const Unit:StringName = &"Unit"
const MatchTeam:StringName = &"MatchTeam"
const Match:StringName = &"Match"

const Player:StringName = &"Player"

const UnitActions:StringName = &"UnitActions"

const Damageable:StringName = &"Damageable"
const WorldBoundaries:StringName = &"WorldBoundaries"
const FogOfWar:StringName = &"FogOfWar"

const Structure:StringName = &"Structure"
const Building:StringName = &"Building"
const GameResource:StringName = &"GameResource"
const TeamAsset:StringName = &"TeamAsset"

const ControlPoint:StringName = &"ControlPoint"
const UI:StringName = &"UI"
const TeamVisible:StringName = &"TeamVisible"

const LevelAudio:StringName = &"LevelAudio"

@warning_ignore_restore("shadowed_global_identifier")

class Units:
	const Tank:StringName = &"UnitClassTank"
	const Artillery:StringName = &"UnitClassArtillery"
	const Soldier:StringName = &"UnitClassSoldier"
	const Transport:StringName = &"UnitClassTransport"
		
static func get_parent_in_group(leaf: Node, group: StringName) -> Node:
	return get_parent_matching(leaf, func(node: Node) -> bool: return node.is_in_group(group) )
	
static func get_parent_with_type(leaf: Node, type: Variant) -> Node:
	return get_parent_matching(leaf, func(node: Node) -> bool: return is_instance_of(node, type) )

static func has_ancestor(leaf: Node, ancestor: Node) -> bool:
	return ancestor.is_ancestor_of(leaf)
	
static func get_parent_matching(leaf: Node, predicate:Callable) -> Node:
	var node:Node = leaf
	while node:
		if predicate.call(node):
			return node
		node = node.get_parent()
	return null
	
static func get_children_in_group(root: Node, group: StringName, return_on_first:bool=false) -> Array[Node]:
	return get_children_matching(root, func(node: Node) -> bool: return node.is_in_group(group), return_on_first)
	
static func get_children_with_type(root: Node, type: Variant, return_on_first:bool=false) -> Array[Node]:
	return get_children_matching(root, func(node: Node) -> bool: return is_instance_of(node, type), return_on_first)

static func get_child_with_type(root: Node, type: Variant) -> Node:
	return get_children_with_type(root, type, true).front()

static func is_child_in_tree(root:Node, child:Node) -> bool:
	return not get_children_matching(root, func(node: Node) -> bool: return node == child, true).is_empty()
	
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

static func is_damageable_root(node:Node) -> bool:
	return node.has_meta(Groups.Damageable)

# Sets meta on the scene root
static func set_scene_root_flag(start:Node, flag:StringName) -> bool:
	var node:Node = get_scene_root(start)
	if node:
		node.set_meta(flag, true)
		return true
	return false
	
static func get_scene_root(start:Node) -> Node:
	if not start:
		return null
	
	var owner:Node = start.owner
	# Prefer user owner of the scene hierachy
	if owner:
		return owner
	# If owner is null it is already the root
	return start
	
static func get_scene_root_if_in_group(start:Node, group:StringName) -> Node:
	var root:Node = get_scene_root(start)
	return root if root and root.is_in_group(group) else null
