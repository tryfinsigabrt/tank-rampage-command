class_name PrecompileTask

signal finished

var scene:PackedScene
var container:Node

func _init(in_scene:PackedScene, in_container:Node) -> void:
	scene = in_scene
	container = in_container
	
func run() -> Signal:
	var node:Node = scene.instantiate()
	container.add_child(node)
	
	var tree:SceneTree = Engine.get_main_loop()
		
	# If there are any particle node types then make sure they are emitting
	var particle_nodes:Array[Node] = Groups.get_children_matching(node, func(n:Node) -> bool:
		return n is GPUParticles3D or n is CPUParticles3D
	)
	
	if particle_nodes:
		await tree.process_frame
		for particle_node in particle_nodes:
			if not particle_node.emitting:
				particle_node.restart()
				particle_node.emitting = true
		await tree.create_timer(0.5).timeout
	
	await tree.process_frame
	await tree.process_frame
	
	node.queue_free()
	
	finished.emit()
	
	return finished
