extends Node3D

@export 
var remove_delay: float = 7.0

@export
var explosion_radius:float = 30.0

@export
var explosion_size_scale:float = 0.075

@onready var orange_shockwave: GPUParticles3D = $"Orange shockwave"
@onready var black_lingering_smoke: GPUParticles3D = $"Black lingering smoke"

func _ready() -> void:
	_set_particle_material_size(orange_shockwave, explosion_radius)
	_set_particle_material_size(black_lingering_smoke, explosion_radius * 0.5)
		
	for child in get_children():
		if child is GPUParticles3D:
			child.restart()

	await get_tree().create_timer(remove_delay).timeout
	queue_free()

func _set_particle_material_size(particles: GPUParticles3D, size:float) -> void:
	var quad_mesh:QuadMesh = particles.draw_pass_1 as QuadMesh
	if not quad_mesh:
		return
	
	var quad_size := size * explosion_size_scale
	quad_mesh.size = Vector2(quad_size, quad_size)
