extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

func _ready() -> void:
	SignalBus.on_unit_command_started.connect(_on_command_started)
	SignalBus.on_unit_command_finished.connect(_on_command_finished)

func _on_team_units_initialized(source: TeamUnits) -> void:
	# All units initially idle
	blackboard.idle_units = source.units.duplicate()
	
func _on_unit_visibility_changed() -> void:
	_evaluate_priorities()
	
func _evaluate_priorities() -> void:
	# TODO: Simplest strategy
	var enemy_teams: EnemyTeams  = blackboard.enemy_teams_info
	var focus_position:Vector3 = blackboard.focus_position
	
	var attack_priorities:Array[Unit]
	
	for team:EnemyTeamUnits in enemy_teams.all_teams():
		# TODO: Use utility AI here to score a list of candidates
		var closest_visible_unit := team.get_closest_visible_unit(focus_position)
		if closest_visible_unit:
			attack_priorities.push_back(closest_visible_unit.unit)
	
	blackboard.attack_priorities = attack_priorities
	
func _on_command_finished(unit:Unit, _command:StringName) -> void:
	if not _is_on_our_team(unit):
		return
	
	var available_units:Array[Unit] = blackboard.idle_units
	available_units.push_back(unit)
	blackboard.idle_units = available_units
	_evaluate_priorities()

func _on_command_started(unit:Unit, _command:StringName) -> void:
	if not _is_on_our_team(unit):
		return
	
	var idle_units:Array[Unit] = blackboard.idle_units
	idle_units.erase(unit)
	blackboard.idle_units = idle_units
	_evaluate_priorities()

func _is_on_our_team(unit:Unit) -> bool:
	var team_units:TeamUnits = blackboard.team_info
	return unit.is_on_team(team_units.team)
