extends MarginContainer

const UTILITY_AI_DEBUG_HUD_THREAT_ROW:PackedScene = preload("uid://xcjp6t74larb")
const UTILITY_CALCULATOR_ID:StringName = &"UtilityCalculator"

@onready var container: VBoxContainer = $Container

var _threat_rows:Dictionary[int, UtilityAIDebugHudThreatRow]

func _ready() -> void:
	SignalBus.on_utility_calculation.connect(_on_utility_calculation)
	SignalBus.on_utility_calculation_complete.connect(_on_utility_calculation_complete)
	
	SignalBus.match_ready.connect(_on_match_ready, CONNECT_ONE_SHOT)
	
func _exit_tree() -> void:
	SignalBus.on_utility_calculation.disconnect(_on_utility_calculation)
	SignalBus.on_utility_calculation_complete.disconnect(_on_utility_calculation_complete)

func _on_utility_calculation(id:StringName, team:int, in_options:Array[UtilityAIOption], chosen_option: UtilityAIOption) -> void:
	# Only update if visible in tree
	if not is_visible_in_tree():
		return
		
	# Only supporting the threat context right now
	if not chosen_option or id != UTILITY_CALCULATOR_ID or chosen_option.context is not UnitThreatContext:
		return
		
	var team_row:UtilityAIDebugHudThreatRow = _threat_rows.get(team)
	if not team_row:
		push_warning("%s: Debug HUD has no row for team=%d" % [name, team])
		return
		
	var options:Array[UtilityAIOption] = in_options.duplicate()
	team_row.update(options, chosen_option)

func _on_utility_calculation_complete(id:StringName, team:int) -> void:
	# Only update if visible in tree
	if not is_visible_in_tree():
		return
		
	# Only supporting the threat context right now
	if id == UTILITY_CALCULATOR_ID:
		var team_row:UtilityAIDebugHudThreatRow = _threat_rows.get(team)
		if team_row:
			team_row.complete()
		
func _on_match_ready(match_object:Match) -> void:
	var player_team:MatchTeam = match_object.player_team
	
	for team in match_object.teams:
		if team == player_team:
			continue
			
		var team_id:int = team.team
		var row:UtilityAIDebugHudThreatRow = UTILITY_AI_DEBUG_HUD_THREAT_ROW.instantiate()
		row.team = team_id
		container.add_child(row)
		_threat_rows[team_id] = row
