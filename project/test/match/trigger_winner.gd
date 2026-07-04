@tool
extends Node

var _triggered:bool

@export
var trigger_player_wins:bool:
	set(value):
		if value == true:
			_trigger_match_ended(true)
@export
var trigger_player_loses:bool:
	set(value):
		if value == true:
			_trigger_match_ended(false)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	SignalBus.match_ended.connect(func(_match_obj:Match) -> void:
		_triggered = true
	, ConnectFlags.CONNECT_ONE_SHOT
	)
	
func _trigger_match_ended(player_wins:bool) -> void:
	if _triggered or Engine.is_editor_hint():
		return
	
	var match_obj:Match = get_tree().get_first_node_in_group(Groups.Match) as Match
	if not match_obj:
		push_error("%s: No Match node in tree!" % name)
		return
		
	var player_team:MatchTeam = match_obj.player_team
	var enemy_teams:Array[MatchTeam]
	for team in match_obj.teams:
		if team != player_team:
			enemy_teams.push_back(team)

	if not player_wins:
		if player_team:
			@warning_ignore("missing_await")
			player_team.eliminate()
		if enemy_teams:
			# Randomly pick a winner
			enemy_teams.shuffle()
			enemy_teams.pop_back()
	
	#Eliminate remaining enemy teams to trigger match ended
	for team in enemy_teams:
		@warning_ignore("missing_await")
		team.eliminate()
