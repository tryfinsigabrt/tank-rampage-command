@tool
extends SetMidpointPosition

func _enter_tree() -> void:
	target_position_key = UnitDirectiveBlackboard.Keys.LoadPosition
	
func _get_other_units(directive:AiUnitDirectives) -> Array[Unit]:
	var explorer := directive.blackboard.target_node as Unit
	var units:Array[Unit]
	if explorer:
		units.push_back(explorer)
	return units
