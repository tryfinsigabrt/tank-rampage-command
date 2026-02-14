class_name UnitScanner extends Node

@export
var threshold_distance:float = 500.0

var my_unit:Unit
var _team:MatchTeam

@onready var sweeper: UnitSweeper = $Sweeper

signal threats_detected(threats:Array[Unit])

func _ready() -> void:
	if not my_unit:
		push_error("%s: my_unit not set" % name)
		queue_free()
	var game:Match = get_tree().get_first_node_in_group(Groups.Match)
	if game:
		_team = game.get_team(my_unit.team)
		if not _team:
			push_warning("%s: could not find MatchTeam for team=%d slow path taken" % [name, _team])
	else:
		push_warning("%s: match not in tree - slow path taken" % name)
		
	sweeper.vision_radius = threshold_distance
		
func _tick() -> void:
	var threats := sweeper.sweep_units(my_unit.global_position, _get_team_units())
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
	
