class_name MaterialUtils

## Sets the overlay material on a non-particle GeometryInstance3D child with ancestor of root
## Optionally checks expected material to avoid unintended overwrites or force it to always set and ignore expected_current_material
static func set_overlay_material(root:Node, new_material:Material, expected_current_material:Material = null, force:bool = false) -> void:
	var all_nodes: Array[Node] = Groups.get_children_matching(root,
		func(node:Node) -> bool:
			var geom:GeometryInstance3D = node as GeometryInstance3D
			# Ignore particles
			if not geom or geom is CPUParticles3D or geom is GPUParticles3D:
				return false
			return force or geom.material_overlay == expected_current_material
	)
	
	for node:GeometryInstance3D in all_nodes:
		node.material_overlay = new_material
	
