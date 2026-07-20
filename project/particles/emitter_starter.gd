class_name EmitterStarter extends Node

@export
var config:Array[ParticleEmissionConfig]

signal _finished

func run() -> void:
	if not config:
		push_error("%s: No configured particle emissions")
		return
	
	# finished, total
	var counts:PackedInt32Array = [0,0]
	for i in config.size():
		var particle_config := config[i]
		var particles_node:GPUParticles3D = get_node_or_null(particle_config.particles) as GPUParticles3D
		if not particles_node:
			push_warning("%s: Could not resolve particle node for index %d" % [name, i])
			continue
			
		counts[1] += 1
		particles_node.finished.connect(func() -> void:
			counts[0] += 1
			if counts[0] >= counts[1]:
				_finished.emit()
		)
		
		var delay:float = randf_range(particle_config.delay.x, particle_config.delay.y)
		if delay > 0:
			get_tree().create_timer(delay, false, false).timeout.connect(particles_node.restart)
		else:
			particles_node.restart()
		
	await _finished
