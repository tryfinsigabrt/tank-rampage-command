class_name AttackPriority

# TODO: Technically this should be a Node3D so non-unit assets can be prioritized
# but keeping as Unit as original implementation was unit-focused
var unit:Unit
var weight:float = 1.0

func _init(in_unit:Unit) -> void:
	unit = in_unit
