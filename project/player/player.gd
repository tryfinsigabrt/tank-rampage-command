class_name Player extends Node3D

@onready var camera: RTSCamera = $RTSCamera
@onready var camera_centering: CameraCentering = $CameraCentering

@export
var player_team:MatchTeam

@onready var player_unit_actions: PlayerUnitActions = $PlayerUnitActions

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
		unit.get_or_add_actions()
	
