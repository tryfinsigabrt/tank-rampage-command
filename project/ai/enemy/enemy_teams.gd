class_name EnemyTeams extends Node

const ENEMY_TEAM_UNITS = preload("uid://reqe3d0kfkhe")

var _teams:Dictionary[int,EnemyTeamUnits] = {}

func add_team(team:int) -> void:
	var enemy_team_units:EnemyTeamUnits = ENEMY_TEAM_UNITS.instantiate()
	enemy_team_units.team = team
	
	add_child(enemy_team_units)
	_teams[team] = enemy_team_units

func get_team(team:int) -> EnemyTeamUnits:
	return _teams.get(team)
	
func get_unit(id:int) -> Unit:
	for team_id in _teams:
		var team := _teams[team_id]
		var unit:Unit = team.get_unit(id)
		if unit:
			return unit
	return null		

func all_teams() -> Array:
	return _teams.values()

func get_all_visible_ids(ids:PackedInt64Array, team_id:int = -1) -> void:
	if team_id < 0:
		for team:EnemyTeamUnits in _teams.values():
			team.get_all_visible_ids(ids)
	else:
		var team := get_team(team_id)
		if team:
			team.get_all_visible_ids(ids)
	
func mark_all_not_visible() -> void:
	for team:EnemyTeamUnits in _teams.values():
		team.mark_all_not_visible()
