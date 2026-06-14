class_name YawPitchWeaponController extends WeaponController

@export
var aiming_component:YawPitchAimingComponent

func aim_at(world_location:Vector3) -> void:
	if not aiming_component:
		return
	aiming_component.aim_at(weapon, world_location)
	weapon.fire_target = world_location

func _get_fire_alignment_global_basis() -> Basis:
	return aiming_component.get_fire_alignment_basis() if aiming_component else super()
		
func get_team_asset() -> Node3D:
	return aiming_component.team_asset if aiming_component else super()
