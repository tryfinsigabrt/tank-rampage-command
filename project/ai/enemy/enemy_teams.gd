class_name EnemyTeams extends Node

const ENEMY_TEAM_UNITS = preload("uid://reqe3d0kfkhe")

var _teams:Dictionary[int,EnemyTeamUnits] = {}

func add_team(team:int) -> void:
	var enemy_team_units:EnemyTeamUnits = ENEMY_TEAM_UNITS.instantiate()
	enemy_team_units.team = team
	
	add_child(enemy_team_units)

func get_team(team:int) -> EnemyTeamUnits:
	return _teams.get(team)

func all_teams() -> Array:
	return _teams.values()

func mark_all_not_visible() -> void:
	for team in _teams.values():
		team.mark_all_not_visible()
