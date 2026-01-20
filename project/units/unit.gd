## Base class for all units in the game
@abstract
class_name Unit extends CharacterBody3D

## Provides the screen direction to instruct the unit to move to
@abstract
func move(input_direction:Vector2) -> void
