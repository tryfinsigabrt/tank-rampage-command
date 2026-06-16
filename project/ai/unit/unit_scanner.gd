class_name UnitScanner extends Node

@export
var threshold_distance:float = 500.0

@export
var my_asset:Node3D

var _team:MatchTeam
var _init:bool

@onready var sweeper: UnitSweeper = $Sweeper
@onready var tick: Timer = $Tick

signal threats_detected(threats:Array[Node3D])

@export
var enabled:bool = true:
	set(value):
		if value == enabled:
			return
		enabled = value
		_on_enable_changed()
	get:
		return enabled

func _on_enable_changed() -> void:
	if not tick:
		return
		
	if enabled:
		if not _init:
			_initialize()
		if _init:
			tick.start()
	else:
		tick.stop()

func _initialize() -> void:
	if not my_asset:
		push_error("%s: my_asset not set" % name)
		queue_free()
		return
		
	var game:Match = get_tree().get_first_node_in_group(Groups.Match)
	if game:
		var team_component := TeamComponent.get_component(my_asset)
		_team = game.get_team(team_component.team)
		if not _team:
			push_warning("%s: could not find MatchTeam for team=%d slow path taken" % [name, team_component.team])
	else:
		push_warning("%s: match not in tree - slow path taken" % name)
		
	sweeper.vision_radius = threshold_distance	
	_init = true
	
func _ready() -> void:
	_on_enable_changed()

## Manually invoke the scanner on demand
func invoke() -> void:
	_tick()
			
func _tick() -> void:
	var threats: Array[Node3D] = sweeper.sweep_assets(my_asset.global_position, _get_team_assets(), _team.team if _team else 0)
	if threats:
		threats_detected.emit(threats)

func _get_team_assets() -> Array[Node3D]:
	if _team:
		return _team.assets
	
	var all_assets:Array[Node] = get_tree().get_nodes_in_group(Groups.TeamAsset)
	var team_assets:Array[Node3D]
	
	var my_team_component := TeamComponent.get_component(my_asset)
	
	for node in all_assets:
		var asset:Node3D = node as Node3D
		if asset:
			var team_component := TeamComponent.get_component(asset, false)
			if my_team_component.on_same_team(team_component):
				team_assets.push_back(asset)
	
	return team_assets
	
