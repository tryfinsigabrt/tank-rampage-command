class_name Components

const Health:StringName = &"HealthComponent"
const Team:StringName = &"TeamComponent"
const Manufacturing:StringName = &"ManufacturingComponent"

static func add_component(name:StringName, comp:Node) -> void:
	assert(comp)
	var root:Node = Groups.get_scene_root(comp)
	if not root:
		push_error("add_component: Could not set component %s:%s" % [name, comp.name])
		return
	
	root.set_meta(name, comp)

static func remove_component(name:StringName, comp:Node) -> void:
	assert(comp)
	var root:Node = Groups.get_scene_root(comp)
	if not root:
		push_error("add_component: Could not set component %s:%s" % [name, comp.name])
		return
	
	root.remove_meta(name)
	
static func get_component(name:StringName, node:Node) -> Node:
	var comp:Node = node.get_meta(name)
	assert(comp, "Could not find component %s on node=%s" % [name, node.name])
	return comp
