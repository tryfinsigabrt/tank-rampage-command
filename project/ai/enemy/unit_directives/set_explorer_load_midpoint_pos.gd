@tool
extends SetMidpointPosition

func _enter_tree() -> void:
	target_position_key = UnitDirectiveBlackboard.Keys.LoadPosition
	
func _get_other_units(directive:AiUnitDirectives) -> Array[Unit]:
	return directive.blackboard.load_units
