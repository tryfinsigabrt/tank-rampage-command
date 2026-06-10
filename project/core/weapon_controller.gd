@abstract
class_name WeaponController extends Node

@warning_ignore("unused_signal")
signal shoot_intent_toggled(shooting:bool)

@export
var weapon:Weapon

@abstract
func aim_at(world_location:Vector3) -> void

func shoot() -> void:
	await weapon.shoot()

func get_fire_global_position() -> Vector3:
	return weapon.global_position

func get_fire_global_forward() -> Vector3:
	return -_get_fire_alignment_global_basis().z

func get_fire_global_right() -> Vector3:
	return _get_fire_alignment_global_basis().x

func get_fire_global_up() -> Vector3:
	return _get_fire_alignment_global_basis().y

func _get_fire_alignment_global_basis() -> Basis:
	return weapon.global_basis

func get_team_asset() -> Node3D:
	return Groups.get_parent_in_group(self, Groups.TeamAsset)
