extends HitVfx

@onready var impact_flash: GPUParticles3D = $ImpactFlash
@onready var spark_burst: GPUParticles3D = $SparkBurst

func start(params:DamageParameters) -> void:
	global_position = params.contact_point
	global_basis = _basis_from_normal(params.contact_normal)
	impact_flash.restart()
	spark_burst.restart()
	impact_flash.emitting = true
	spark_burst.emitting = true

func _basis_from_normal(normal: Vector3) -> Basis:
	var up := normal.normalized()
	if up.is_zero_approx():
		return Basis.IDENTITY

	var tangent_seed := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var right := tangent_seed.cross(up).normalized()
	var forward := up.cross(right).normalized()
	return Basis(right, up, forward)
