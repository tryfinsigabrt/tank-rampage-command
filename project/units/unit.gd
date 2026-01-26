## Base class for all units in the game
@abstract
class_name Unit extends CharacterBody3D

@export
var team:int

## Provides the screen direction to instruct the unit to move to
@abstract
func move(input_direction:Vector2) -> void

@abstract
func aim_at(world_location:Vector3) -> void

@abstract
func shoot() -> void

func get_fire_global_position() -> Vector3:
	return global_position

func get_fire_global_forward() -> Vector3:
	return global_forward

func get_fire_global_right() -> Vector3:
	return global_right

func get_fire_global_up() -> Vector3:
	return global_up
	
func _orientation_basis() -> Node3D:
	return self
	
var global_forward:Vector3:
	get:
		return -_orientation_basis().global_basis.z

var forward:Vector3:
	get:
		return -_orientation_basis().basis.z
		
var global_right:Vector3:
	get:
		return _orientation_basis().global_basis.x

var right:Vector3:
	get:
		return _orientation_basis().basis.x
		
var global_up:Vector3:
	get:
		return _orientation_basis().global_basis.y
		
var up:Vector3:
	get:
		return _orientation_basis().basis.y
