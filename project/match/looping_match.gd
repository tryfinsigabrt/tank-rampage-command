extends Node

@export
var match_restart_delay:float = 4.0

var player_team:MatchTeam
	
var _is_restarting:bool

func _ready() -> void:
	SignalBus.match_ready.connect(_on_match_ready)
	SignalBus.match_ended.connect(_on_match_complete)
	SignalBus.match_team_eliminated.connect(_on_team_eliminated)
	
func _on_match_ready(match_object:Match) -> void:
	player_team = match_object.player_team
	
func _on_team_eliminated(match_team:MatchTeam) -> void:
	if match_team == player_team:
		print_debug("%s: Player team=%d->%s eliminated" % name, match_team.team, match_team.name)
		_restart()
	
func _on_match_complete(_match_object:Match) -> void:
	_restart()
	
func _restart() -> void:
	if _is_restarting:
		return
	
	_is_restarting = true
	await get_tree().create_timer(match_restart_delay).timeout
	get_tree().reload_current_scene()
