extends Node3D

@onready var emitter_starter: EmitterStarter = %EmitterStarter

@export_range(0.0, 1e9, 0.01, "or_greater")
var explosion_scale:float = 1.0

func _ready() -> void:
	if not is_equal_approx(explosion_scale, 1.0):
		for node in get_children():
			if node is GPUParticles3D:
				_set_particles_scale(node)
			
	await emitter_starter.run()
	queue_free()


func _set_particles_scale(particles:GPUParticles3D) -> void:
	var process_material := particles.process_material as ParticleProcessMaterial
	if not process_material:
		return
	
	# Duplicate so don't affect the shared resource
	process_material = process_material.duplicate()
	
	process_material.scale_min *= explosion_scale
	process_material.scale_max *= explosion_scale
	
	particles.process_material = process_material
