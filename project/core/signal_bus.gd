extends Node

@warning_ignore_start("unused_signal")

signal on_paused(paused:bool)

signal on_unit_deselected(unit:Unit)
signal on_unit_selected(unit: Unit)

signal on_unit_move_issued(unit: Unit, target_position: Vector3)
signal on_unit_move_canceled(unit: Unit, target_position: Vector3)
signal on_destination_reached(unit: Unit, target_position: Vector3)

signal on_unit_command_finished(unit:Unit, command: StringName)

## Reported for damage on any collidable object
## collided objects with a Damageable group are delivered the events directly
signal on_any_damage(damage_parameters:DamageParameters)

signal on_unit_health_changed(unit:Unit, previous_health:float, current_health:float)
signal on_unit_killed(unit:Unit, damage_parameters:DamageParameters)

@warning_ignore_restore("unused_signal")
