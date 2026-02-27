class_name FogOfWarVisibilityInstance extends MultiMeshInstance2D

@export
var fog_of_war_scale:float = 0.4

@export
var max_instances:int = 1000

# Transform to hide the remaining unused slots in the buffer
const HIDDEN_TRANSFORM:Transform2D = Transform2D(0.0, Vector2.ZERO, 0.0, -Vector2.INF)

func _ready() -> void:
	var multi_mesh := MultiMesh.new()
	
	# set the format (2D)
	multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
	
	# Assign the Mesh
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE # We use 1x1 because wescale it in update
	multi_mesh.mesh = quad
	
	# Set the count
	multi_mesh.instance_count = max_instances
	
	multimesh = multi_mesh

# These all should be interactable instances and have a "vision" field	
func update(instances: Array[Node3D]) -> void:
	var mesh := multimesh
	var active_count:int = instances.size()
	
	for i in active_count:
		var node:Node3D = instances[i]
		if is_instance_valid(node) and node.is_in_group(Groups.Interactable):			
			var pos:Vector3 = node.global_position
			
			var projected_pos:Vector2 = Vector2(
				pos.x * fog_of_war_scale,
				pos.z * fog_of_war_scale
			)
			
			var radius_scale:float = node.vision * fog_of_war_scale
			var xform:Transform2D = Transform2D(0.0, Vector2(radius_scale, radius_scale), 0.0, projected_pos)
			mesh.set_instance_transform_2d(i, xform)
		else:
			mesh.set_instance_transform_2d(i, HIDDEN_TRANSFORM)
		
		# apply transform per visible unit
	for i in range(active_count, mesh.instance_count):
		mesh.set_instance_transform_2d(i, HIDDEN_TRANSFORM)
		
	# TODO: Handle buildings with custom shader, setting "visibility" to a modulated value like 0.4
