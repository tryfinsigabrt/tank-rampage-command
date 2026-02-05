class_name Match extends Node3D

var _match_teams:Dictionary[int, MatchTeam] = {}
var _active_teams:Dictionary[int, MatchTeam] = {}

func _ready() -> void:
	SignalBus.match_team_lost.connect(_on_team_lost)
	var teams:Array[Node] = get_tree().get_nodes_in_group(Groups.MatchTeam)
	for node in teams:
		var team:MatchTeam = node as MatchTeam
		if not team:
			push_warning("%s: node=%s is in group 'MatchTeam' but not a MatchTeam type" % [name, node.name])
			continue
		_match_teams[team.team] = team
	
	_active_teams.assign(_match_teams)
	_wait_for_ready()

func _wait_for_ready() -> void:
	var counter:PackedInt32Array = [0]
	var connection:Array[Callable] = []
	connection.push_back(func(match_team:MatchTeam):
		if match_team.team in _match_teams:
			counter[0] += 1
			if counter[0] == _match_teams.size():
				SignalBus.match_ready.emit(self)
				SignalBus.match_team_ready.disconnect(connection.front())
	)
	SignalBus.match_team_ready.connect(connection.front())
	
func _on_team_lost(team:MatchTeam) -> void:
	print_debug("%s: team=%d -> %s lost" % [name, team.team, team.name])
	if _active_teams.erase(team.team):
		if _active_teams.is_empty():
			SignalBus.match_ended.emit(self)
