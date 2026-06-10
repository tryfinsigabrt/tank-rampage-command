class_name UnitWeaponController extends WeaponController

@export
var unit:Unit

func aim_at(world_location:Vector3) -> void:
	return unit.aim_at(world_location)

func shoot() -> void:
	unit.shoot()

func get_fire_global_position() -> Vector3:
	return unit.get_fire_global_position()

func get_fire_global_forward() -> Vector3:
	return unit.get_fire_global_forward()

func get_fire_global_right() -> Vector3:
	return unit.get_fire_global_right()

func get_fire_global_up() -> Vector3:
	return unit.get_fire_global_up()

func get_team_asset() -> Node3D:
	return unit
