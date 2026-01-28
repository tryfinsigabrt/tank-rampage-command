extends Node

@warning_ignore_start("unused_signal")

signal on_unit_deselected(unit:Unit)
signal on_unit_selected(unit: Unit)

signal on_unit_move_issued(unit: Unit, target_position: Vector3)
signal on_unit_move_canceled(unit: Unit, target_position: Vector3)
signal on_destination_reached(unit: Unit, target_position: Vector3)

@warning_ignore_restore("unused_signal")
