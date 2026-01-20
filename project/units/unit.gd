## Base class for all units in the game
@abstract
class_name Unit extends CharacterBody3D

## Provides the screen direction to instruct the unit to move to
@abstract
func move(input_direction:Vector2) -> void

@abstract
func aim_at(world_location:Vector3) -> void


var global_foward:Vector3:
	get:
		return -global_transform.basis.z

var global_right:Vector3:
	get:
		return global_transform.basis.x

var global_up:Vector3:
	get:
		return global_transform.basis.y
