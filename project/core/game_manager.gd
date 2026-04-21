extends Node

@onready var game_timer: GameTimer = %GameTimer
@onready var scene_manager: SceneManager = %SceneManager

var fog_of_war:bool

func _ready() -> void:
	var node:FogOfWar = get_tree().get_first_node_in_group(Groups.FogOfWar) as FogOfWar
	if node and node.enable:
		fog_of_war = true
		
func is_owned_by_player(node: Node) -> bool:
	var player_team:MatchTeam = get_player_team()
	return player_team and player_team.is_ancestor_of(node)

func get_player_team() -> MatchTeam:
	var match_obj:Match = get_tree().get_first_node_in_group(Groups.Match)
	if not match_obj:
		return null
	var player_team:MatchTeam = match_obj.player_team
	if player_team:
		return player_team
	
	print_debug("%s: Player Team not assigned to match yet - taking slow path" % name)
		
	# May have been called too early - take slower path
	var player:Player = get_tree().get_first_node_in_group(Groups.Player)
	if not player:
		push_warning("%s: No player node in scene!" % name)
		return null
		
	player_team = Groups.get_parent_in_group(player, Groups.MatchTeam)
	return player_team

func find_match_team_by_id(team:int) -> MatchTeam:
	for match_team:MatchTeam in get_tree().get_nodes_in_group(Groups.MatchTeam):
		if match_team.team == team:
			return match_team
	return null
	
func find_match_team(node: Node) -> MatchTeam:
	var teams: Array[Node] = get_tree().get_nodes_in_group(Groups.MatchTeam)
	var team_component:TeamComponent = TeamComponent.get_component(node, false)
	
	var finder:Callable
	if team_component:
		var team:int = team_component.team
		finder = func(match_team:MatchTeam) -> bool:
			return match_team.team == team
	else:
		finder = func(match_team:MatchTeam) -> bool:
			return match_team.is_ancestor_of(node)
	
	for match_team:MatchTeam in teams:
		if finder.call(match_team):
			return match_team
			
	return null
