@tool
class_name ShootVfx extends Node3D

enum SizePreset {
	SMALL,
	MEDIUM,
	LARGE,
}

@onready var projectile: GPUParticles3D = $Projectile
@onready var muzzle_flash: GPUParticles3D = $MuzzleFlash

@export var yaw_correction_degrees: float = 90.0

func orient(fire_position: Vector3, fire_right: Vector3, fire_up: Vector3, fire_forward: Vector3) -> void:
	global_position = fire_position
	global_basis = Basis(fire_right.normalized(), fire_up.normalized(), fire_forward.normalized())
	rotate_object_local(Vector3.UP, deg_to_rad(yaw_correction_degrees))

func shoot() -> void:
	projectile.restart()
	muzzle_flash.restart()
	projectile.emitting = true
	muzzle_flash.emitting = true
