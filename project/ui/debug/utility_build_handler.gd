class_name UtilityBuildHandler extends UtilityAIHandler

const BUILDING_CALCULATOR_ID:StringName = &"BuildUtilityCalculator"

func supports(utility_node_name:StringName) -> bool:
	return utility_node_name == BUILDING_CALCULATOR_ID

func start(_team:int, _index:int, _scores: Dictionary[UtilityAIOption, float], _chosen_option:UtilityAIOption) -> void:
	pass

func option_action_to_string(option:UtilityAIOption) -> String:
	return ""

func option_context_to_string(option:UtilityAIOption) -> String:
	return ""

func finish() -> void:
	pass
