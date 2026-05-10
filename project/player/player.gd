class_name Player extends Node3D

@onready var camera: RTSCamera = $RTSCamera
@onready var camera_centering: CameraCentering = $CameraCentering

@export
var player_team:MatchTeam

@onready var player_unit_actions: PlayerTeamActions = $PlayerTeamActions

func _ready() -> void:
	if not player_team:
		push_error("%s: player_team not assigned to player" % name)
		return
		
	player_unit_actions.team = player_team.team
	
	camera_centering.camera = camera
	camera_centering.player_team = player_team
	
	SignalBus.match_ready.connect(_on_match_ready.unbind(1), ConnectFlags.CONNECT_ONE_SHOT)
	
	camera_centering.initialize()
	
func _on_match_ready() -> void:
	# Ensure idle action added
	for unit in player_team.units:
		_init_unit(unit)
	
	# Initialize other units that come in after match starts
	# TODO: Maybe the match team should fire a signal for assets added 
	# to the team instead of filtering from global
	SignalBus.on_team_asset_added.connect(_on_team_asset_added)

func _init_unit(unit:Unit) -> void:
	unit.get_or_add_actions()
	
func _on_team_asset_added(asset:Node3D) -> void:
	var team_comp:TeamComponent = Components.get_component(Components.Team, asset)
	if not team_comp:
		return
	
	if not team_comp.is_on_team(player_team.team):
		return
	
	if asset is Unit:
		_init_unit(asset)
