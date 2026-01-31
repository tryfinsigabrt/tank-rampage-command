class_name EnemyTeamBlackboard extends Blackboard

class Keys:
	const enemy_teams_info:StringName = &"enemy_teams_info"
	const team_info:String = &"team_info"
	const focus_position:StringName = &"focus_position"
	const team:StringName = &"team"

var enemy_teams_info:EnemyTeams:
	get:
		return get_value(Keys.enemy_teams_info)
	set(value):
		set_value(Keys.enemy_teams_info, value)

var team_info:TeamUnits:
	get:
		return get_value(Keys.team_info)
	set(value):
		set_value(Keys.team_info, value)
		
func get_enemy_team_info(in_team:int) -> EnemyTeamUnits:
	var enemy_teams:EnemyTeams = enemy_teams_info
	if enemy_teams:
		return enemy_teams.get_team(in_team)
	return null

var team:int:
	get:
		return get_value(Keys.team, 0)
	set(value):
		set_value(Keys.team, value)
	
var focus_position:Vector3:
	get:
		return get_value(Keys.focus_position, Vector3.ZERO)
	set(value):
		set_value(Keys.focus_position, value)
