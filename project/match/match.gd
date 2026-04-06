class_name Match extends Node3D

var _match_teams:Dictionary[int, MatchTeam] = {}
var _active_teams:Dictionary[int, MatchTeam] = {}

var _game_over:bool
var _player_team:int = -1

var teams:Array[MatchTeam]:
	get: return _match_teams.values()
	
var active_teams:Array[MatchTeam]:
	get: return _active_teams.values()

var player_team:MatchTeam:
	get: return _match_teams.get(_player_team)
	
var winner:MatchTeam:
	get: return _active_teams.values().front() if _game_over and not _active_teams.is_empty() else null
	
func get_team(team:int) -> MatchTeam:
	return _match_teams.get(team)
	
func _ready() -> void:
	SignalBus.match_team_eliminated.connect(_on_team_lost)
	var all_teams:Array[Node] = get_tree().get_nodes_in_group(Groups.MatchTeam)
	var player_nodes:Array = get_tree().get_nodes_in_group(Groups.Player).filter(func(node: Node) -> bool:
		return node is Node3D and node.is_visible_in_tree()
	)
	
	if player_nodes.is_empty():
		push_warning("%s: No player nodes found!" % name)
	elif player_nodes.size() > 1:
		push_warning("%s: Multiple player nodes found: %s" % [name, player_nodes])
	var player_node:Node = player_nodes.front() if not player_nodes.is_empty() else null
		
	for node in all_teams:
		var team:MatchTeam = node as MatchTeam
		if not team:
			push_warning("%s: node=%s is in group 'MatchTeam' but not a MatchTeam type" % [name, node.name])
			continue
		_match_teams[team.team] = team
		if _player_team < 0 and Groups.has_ancestor(player_node, team):
			print_debug("%s: Found player team: %d -> %s" % [name, team.team, team.name])
			_player_team = team.team
			team.is_player_team = true
				
	_active_teams.assign(_match_teams)
	_wait_for_ready()

func _is_player_team(match_team:MatchTeam) -> bool:
	# Node designated with "Player" should be a child under the match team
	return not Groups.get_children_in_group(match_team, Groups.Player, true).is_empty()
	
func _wait_for_ready() -> void:
	var counter:PackedInt32Array = [0]
	# Using an array of size 1 so we can self-reference the callable to disconnect after
	# all teams have notified match_team_ready
	var connection:Array[Callable] = []
	connection.push_back(func(match_team:MatchTeam) -> void:
		if match_team.team in _match_teams:
			counter[0] += 1
			if counter[0] == _match_teams.size():
				SignalBus.match_ready.emit(self)
				SignalBus.match_team_ready.disconnect(connection.front())
	)
	SignalBus.match_team_ready.connect(connection.front())
	
func _on_team_lost(team:MatchTeam) -> void:
	if _game_over:
		return
		
	print_debug("%s: team=%d -> %s lost" % [name, team.team, team.name])
	if _active_teams.erase(team.team):
		if _active_teams.size() <= 1:
			_game_over = true
			SignalBus.match_ended.emit(self)
