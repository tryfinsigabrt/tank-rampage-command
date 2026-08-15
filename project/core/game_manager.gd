extends Node

@onready var game_timer: GameTimer = %GameTimer
@onready var scene_manager: SceneManager = %SceneManager
@onready var audio_manager: AudioManager = %AudioManager
@onready var _game_config_holder: GameConfigHolder = %GameConfigHolder
@onready var _music_manager: MusicManager = $MusicManager

# If called before data refreshed then just query dynamically
var _scene_ready:bool

var _exiting_scene:Node
var _entering_scene:Node

var fog_of_war:bool:
	get:
		if _scene_ready:
			return fog_of_war
			
		var fow_node := fog_of_war_node
		return fow_node.enable if is_instance_valid(fow_node) else false 

var fog_of_war_node:FogOfWar:
	get:
		var fow_node: FogOfWar = fog_of_war_node if _scene_ready else _get_fog_of_war()
		return fow_node if is_instance_valid(fow_node) else null

## Used for testing to reveal whole map to player
var fog_of_war_visibility_override:bool:
	get:
		# When fog of war is not visible then it is enabled for AI calculations but player can see all
		return not fog_of_war or not fog_of_war_node.visible
	
var game_config:GameConfig:
	get:
		return _game_config_holder.game_config
		
func _ready() -> void:
	reset_world_state()
	
	scene_manager.scene_leaving.connect(func(scene:Node) -> void:
		_scene_ready = false
		_entering_scene = null
		_exiting_scene = scene
	)
	scene_manager.scene_entering.connect(func(scene:Node) -> void:
		_entering_scene = scene
	)
	scene_manager.scene_changed.connect(reset_world_state.unbind(1))

func start_menu_music() -> void:
	_music_manager.start_menu_music()
	
func reset_world_state() -> void:
	_scene_ready = true
	game_timer.reset()
	
	fog_of_war_node = _get_fog_of_war()
	if fog_of_war_node and fog_of_war_node.enable:
		fog_of_war = true
	else:
		fog_of_war = false
		
func _get_fog_of_war() -> FogOfWar:
	return get_tree().get_first_node_in_group(Groups.FogOfWar) as FogOfWar	
	
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

func is_scene_exiting(node:Node) -> bool:
	if node.is_queued_for_deletion():
		return true
	# Check if exiting scene is valid and if node is not part of entering scene
	if is_instance_valid(_exiting_scene) and (not is_instance_valid(_entering_scene) or not _entering_scene.is_ancestor_of(node)):
		return true
	return false
