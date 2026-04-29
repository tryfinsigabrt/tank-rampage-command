extends HitVfx

@onready var hit_emitter: CPUParticles3D = $HitEmitter

func start(params:DamageParameters) -> void:
	hit_emitter.global_position = params.contact_point
	hit_emitter.restart()
