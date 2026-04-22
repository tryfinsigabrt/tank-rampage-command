class_name ShootVfx extends Node3D

@onready var projectile: GPUParticles3D = $Projectile

@export var yaw_correction_degrees: float = 90.0


func orient(fire_position: Vector3, fire_right: Vector3, fire_up: Vector3, fire_forward: Vector3) -> void:
	global_position = fire_position
	global_basis = Basis(fire_right.normalized(), fire_up.normalized(), -fire_forward.normalized())
	rotate_object_local(Vector3.UP, deg_to_rad(yaw_correction_degrees))

func shoot() -> void:
	projectile.restart()
	projectile.emitting = true
