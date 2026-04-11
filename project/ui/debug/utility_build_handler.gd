class_name UtilityBuildHandler extends UtilityAIHandler

const BUILDING_CALCULATOR_ID:StringName = &"BuildUtilityCalculator"

var _build_counts_by_type:Dictionary[ConstructionResource.Type, int]
var _army_counts_by_type:Dictionary[ConstructionResource.Type, int]
var _match_team:MatchTeam
var _values:PackedStringArray

func supports(utility_node_name:StringName) -> bool:
	return utility_node_name == BUILDING_CALCULATOR_ID

func start(team:int, _index:int, _scores: Dictionary[UtilityAIOption, float], chosen_option:UtilityAIOption) -> void:
	if not _match_team:
		var team_nodes: Array[Node] = get_tree().get_nodes_in_group(Groups.MatchTeam)
		for node in team_nodes:
			var match_team:MatchTeam = node as MatchTeam
			if match_team and match_team.team == team:
				_match_team = match_team
				break
	
	var context:BuildUtilityContext = chosen_option.context
	var type:ConstructionResource.Type = context.construction.type
	_build_counts_by_type[type] = _build_counts_by_type.get(type, 0) + 1

func option_action_to_string(option:UtilityAIOption) -> String:
	var context:BuildUtilityContext = option.context
	return EnumUtils.enum_to_string(ConstructionResource.Type, context.construction.type)

func option_context_to_string(_option:UtilityAIOption) -> String:
	_values.clear()
	_values.push_back("BUILT: ")
	for type in _build_counts_by_type:
		_values.push_back("%s: %d " % [EnumUtils.enum_to_string(ConstructionResource.Type, type), _build_counts_by_type[type]])
	_values.push_back("\n")
	
	if _match_team:
		_values.push_back("ARMY: ")
		_army_counts_by_type.clear()
		for unit in _match_team.units:
			var type:ConstructionResource.Type = ConstructionResource.type_from_unit_class(unit.unit_class)
			_army_counts_by_type[type] = _army_counts_by_type.get(type, 0) + 1
		
		for type in _army_counts_by_type:
			_values.push_back("%s: %d " % [EnumUtils.enum_to_string(ConstructionResource.Type, type), _army_counts_by_type[type]])
	return "".join(_values)
	
func finish() -> void:
	pass
