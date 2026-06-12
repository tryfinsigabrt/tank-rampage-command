class_name DefaultWeaponController extends WeaponController

@export
var asset:Node3D

func aim_at(world_location:Vector3) -> void:
	weapon.look_at(world_location)
	
func get_team_asset() -> Node3D:
	return asset if asset else super()
