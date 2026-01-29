@tool
class_name CommandActionLeaf extends ActionLeaf

var my_action:StringName

func before_run(_actor: Node, blackboard: Blackboard) -> void:
	my_action = blackboard.get_value(UnitBlackboard.Keys.Action)
	
func _check_running_state(blackboard: Blackboard) -> int:
	var current_action:StringName = blackboard.get_value(UnitBlackboard.Keys.Action, &"")
	if current_action != my_action:
		print_debug("%s: current_action=%s changed from %s" % [name, current_action, my_action])
		return FAILURE
	return RUNNING if _should_continue_running(blackboard) else FAILURE
	
func _should_continue_running(_blackboard: Blackboard) -> bool:
	return true
