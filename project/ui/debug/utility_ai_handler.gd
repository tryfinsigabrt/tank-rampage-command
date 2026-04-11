@abstract
class_name UtilityAIHandler extends Node
	
@abstract
func supports(utility_node_name:StringName) -> bool

func start(_team:int, _index:int, _scores: Dictionary[UtilityAIOption, float], _chosen_option:UtilityAIOption) -> void:
	pass

@abstract
func option_action_to_string(option:UtilityAIOption) -> String

@abstract
func option_context_to_string(option:UtilityAIOption) -> String

func finish() -> void:
	pass
