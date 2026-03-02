class_name FogOfWarVisibilityInstance extends MultiMeshInstance2D

@export
var max_instances:int = 1000

# Transform to hide the remaining unused slots in the buffer
const HIDDEN_TRANSFORM:Transform2D = Transform2D(0.0, Vector2.ZERO, 0.0, -Vector2.INF)

@export
var fog_of_war:FogOfWar

func _ready() -> void:
	if not fog_of_war:
		push_error("%s: FogOfWar node not set to do 3D to viewport projection" % name)
		return
		
	var multi_mesh := MultiMesh.new()
	
	# set the format (2D)
	multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
	
	# Enable per-instance colors so the MultiMesh instance buffer
	# populates the color attribute slot that the GLES3 2D canvas
	# shader expects. Without this, WebGL rejects the draw call.
	# This manifests as a warning in console: "GL_INVALID_OPERATION: glDrawElements: Vertex shader input type does not match the type of the bound vertex attribute."
	# See also github issue https://github.com/godotengine/godot/issues/81926
	# The issue should have been fixed but falling back to building the Quad manually and sending an explicit color array (WHITE)
	# On Vulkan/DirectX the missing array is being defaulted but this does not occur for GLES3

	multi_mesh.use_colors = true
	
	# Build a 1x1 quad as an ArrayMesh with vec2 positions + per-vertex
	# color so vertex attributes match the 2D canvas shader on WebGL.
	# QuadMesh uses vec3 positions which causes GL_INVALID_OPERATION
	# on strict WebGL drivers due to attribute type mismatch.
	multi_mesh.mesh = _create_quad_mesh_2d()
	
	# Set the count
	multi_mesh.instance_count = max_instances
	
	multimesh = multi_mesh

## Creates a 1x1 unit quad using an ArrayMesh with vec2 vertex positions.
## This avoids the WebGL vertex attribute type mismatch that occurs when
## using QuadMesh (which emits vec3 positions) inside a 2D draw path.
static func _create_quad_mesh_2d() -> ArrayMesh:
	var vertices := PackedVector2Array([
		Vector2(-0.5, -0.5),
		Vector2( 0.5, -0.5),
		Vector2( 0.5,  0.5),
		Vector2(-0.5,  0.5),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	var colors := PackedColorArray([
		Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE,
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh

# These all should be interactable instances and have a "vision" field	
func update(instances: Array[Node3D]) -> void:
	if not fog_of_war:
		return
		
	var mesh := multimesh
	var active_count:int = instances.size()
	var viewport_scale:Vector2 = fog_of_war.world_to_view_scale
	
	for i in active_count:
		var node:Node3D = instances[i]
		if is_instance_valid(node) and node.is_in_group(Groups.Interactable):			
			var pos:Vector3 = node.global_position
			var projected_pos:Vector2 = fog_of_war.project_position(pos)
			
			var vision_radius:Vector2 = node.vision * viewport_scale
			var xform:Transform2D = Transform2D(0.0, vision_radius, 0.0, projected_pos)
			mesh.set_instance_transform_2d(i, xform)
			mesh.set_instance_color(i, Color.WHITE)
		else:
			mesh.set_instance_transform_2d(i, HIDDEN_TRANSFORM)
			mesh.set_instance_color(i, Color(0, 0, 0, 0))
		
		# apply transform per visible unit
	for i in range(active_count, mesh.instance_count):
		mesh.set_instance_transform_2d(i, HIDDEN_TRANSFORM)
		mesh.set_instance_color(i, Color(0, 0, 0, 0))
		
	# TODO: Handle buildings with custom shader, setting "visibility" to a modulated value like 0.4
