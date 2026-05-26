class_name UnitScanner extends Node

@export
var threshold_distance:float = 500.0

@export
var my_unit:Unit

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
	if not my_unit:
		push_error("%s: my_unit not set" % name)
		queue_free()
		return
		
	var game:Match = get_tree().get_first_node_in_group(Groups.Match)
	if game:
		_team = game.get_team(my_unit.team)
		if not _team:
			push_warning("%s: could not find MatchTeam for team=%d slow path taken" % [name, my_unit.team])
	else:
		push_warning("%s: match not in tree - slow path taken" % name)
		
	sweeper.vision_radius = threshold_distance	
	_init = true
	
func _ready() -> void:
	_on_enable_changed()
		
func _tick() -> void:
	var threats: Array[Node3D] = sweeper.sweep_assets(my_unit.global_position, _get_team_units(), _team.team if _team else 0)
	if threats:
		threats_detected.emit(threats)

func _get_team_units() -> Array[Unit]:
	if _team:
		return _team.units
	
	var all_units:Array[Node] = get_tree().get_nodes_in_group(Groups.Unit)
	var team_units:Array[Unit]
	
	for node in all_units:
		var unit:Unit = node as Unit
		if my_unit.on_same_team(unit):
			team_units.push_back(unit)
	
	return team_units
	
