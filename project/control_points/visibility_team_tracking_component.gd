class_name VisibilityTeamTrackingComponent extends Node

var _root:Node3D
var _visibility_by_team:Dictionary[int,Callable]

static var _FALSE_CALLABLE:Callable = func() -> bool: return false

func _ready() -> void:
	_root = Groups.get_scene_root(self) as Node3D
	if not _root:
		assert("%s: Not added to a scene that has a Node3D!" % name)
		return
			
	SignalBus.match_ready.connect(_initialize, ConnectFlags.CONNECT_ONE_SHOT)
		
func is_visible_to_team(team:int) -> bool:
	return _visibility_by_team.get(team, _FALSE_CALLABLE).call()

func get_visibility_for_each_team(callback:Callable) -> void:
	for team in _visibility_by_team:
		var is_visible:bool = _visibility_by_team[team].call()
		callback.call(team, is_visible)
		
func _initialize(match_obj:Match) -> void:
	var player_team:MatchTeam = match_obj.player_team
	var player_team_id:int = player_team.team if player_team else -1
	
	var is_fow_enabled:bool = GameManager.fog_of_war
			
	for match_team in match_obj.teams:
		var team:int = match_team.team
		if not is_fow_enabled:
			# Always visible if fow not enabled
			_visibility_by_team[team] = func() -> bool: return true
			continue
		
		# Player team handled by fog of war node
		if team == player_team_id:
			var fow := GameManager.fog_of_war_node
			if fow:
				_visibility_by_team[team] = func() -> bool:
					return fow.is_node_visible(_root) if is_instance_valid(fow) else false
			else:
				push_error("%s: Could not retrieve fog of war node when FOW enabled!" % name)
				_visibility_by_team[team] = func() -> bool: return true
		else:
			# Derive AI visibility from team visibility component that uses AI vision
			var visibility_component := match_team.team_visibility_component
			_visibility_by_team[team] = func() -> bool:
				return visibility_component.is_visible(_root) if is_instance_valid(visibility_component) else false
		
