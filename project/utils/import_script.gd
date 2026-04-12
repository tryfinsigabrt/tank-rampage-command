@tool
extends EditorScenePostImport

# Replaces imported GLB materials with shared project materials based on the
# imported material name, as named within the Blender file.
#
# Blender to Godot workflow:
# 1. In Blender, assign material slots on the mesh using the names of materials
# 	in `props/shared/materials` directory, eg. `brick_wall_material`.
# 2. UV unwrap and scale the UVs in Blender so the texture density matches what
#    you want in game. This script only swaps materials, it does not change UVs.
# 3. Export the model as `.glb`.
# 5. In Godot, select the `.glb`, open the Import dock, and set
#    `Import Script` to `res://utils/import_script.gd`.
# 6. Click `Reimport`.
# 7. After import, any mesh surface using one of the supported material names
#    will be replaced with the matching shared material from
#    `res://props/shared/materials/`.
#
# Notes:
# - This works with a single mesh using multiple surfaces or with multiple mesh
#   nodes in the same imported scene.
# - If a surface material name does not match one of the supported names, it is
#   left unchanged.

const MATERIAL_PATHS := {
	"brick_wall_material": "res://props/shared/materials/brick_wall_material.tres",
	"window_material": "res://props/shared/materials/window_material.tres",
	"corrugated_metal_material": "res://props/shared/materials/corrugated_metal_material.tres",
	"trim_material": "res://props/shared/materials/trim_material.tres",
}

var _material_cache: Dictionary = {}


func _post_import(scene: Node) -> Object:
	print("[import_script] Starting import remap for scene: %s" % scene.name)
	_replace_materials_recursive(scene)
	print("[import_script] Finished import remap for scene: %s" % scene.name)
	return scene


func _replace_materials_recursive(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null:
		_replace_mesh_instance_materials(mesh_instance)

	for child in node.get_children():
		_replace_materials_recursive(child)


func _replace_mesh_instance_materials(mesh_instance: MeshInstance3D) -> void:
	var mesh_instance_label := _get_node_label(mesh_instance)
	print("[import_script] Inspecting mesh instance: %s" % mesh_instance_label)

	var replacement_override := _get_replacement_material(mesh_instance.material_override)
	if replacement_override != null:
		print(
			"[import_script] Replaced material_override on %s with %s"
			% [mesh_instance_label, replacement_override.resource_path]
		)
		mesh_instance.material_override = replacement_override

	var mesh := mesh_instance.mesh
	if mesh == null:
		print("[import_script] Mesh instance has no mesh: %s" % mesh_instance_label)
		return

	for surface_index in mesh.get_surface_count():
		var source_material := mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh.surface_get_material(surface_index)

		var material_name := _get_material_lookup_name(source_material)
		print(
			"[import_script] Surface %d on %s uses material: %s"
			% [surface_index, mesh_instance_label, material_name]
		)

		var replacement_material := _get_replacement_material(source_material)
		if replacement_material == null:
			print(
				"[import_script] No replacement configured for surface %d on %s"
				% [surface_index, mesh_instance_label]
			)
			continue

		mesh_instance.set_surface_override_material(surface_index, replacement_material)
		print(
			"[import_script] Replaced surface %d on %s with %s"
			% [surface_index, mesh_instance_label, replacement_material.resource_path]
		)


func _get_replacement_material(source_material: Material) -> Material:
	if source_material == null:
		return null

	var material_name := _get_material_lookup_name(source_material)
	if material_name.is_empty() or not MATERIAL_PATHS.has(material_name):
		return null

	if not _material_cache.has(material_name):
		_material_cache[material_name] = load(MATERIAL_PATHS[material_name])
		print(
			"[import_script] Loaded replacement material %s for %s"
			% [MATERIAL_PATHS[material_name], material_name]
		)

	return _material_cache[material_name]


func _get_material_lookup_name(source_material: Material) -> String:
	if not source_material.resource_name.is_empty():
		return source_material.resource_name

	var material_name := source_material.get_name()
	if material_name.begins_with("<") and material_name.ends_with(">"):
		return ""

	return material_name


func _get_node_label(node: Node) -> String:
	var names: Array[String] = []
	var current: Node = node

	while current != null:
		names.push_front(current.name)
		current = current.get_parent()

	return "/".join(names)
