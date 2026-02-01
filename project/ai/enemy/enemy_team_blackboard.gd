class_name EnemyTeamBlackboard extends Blackboard

@warning_ignore("unused_signal")
signal on_unit_visibility_changed

signal on_attacking_units_changed

signal on_attacking_priorities_changed
 
class Keys:
	const enemy_teams_info:StringName = &"enemy_teams_info"
	const team_info:String = &"team_info"
	const focus_position:StringName = &"focus_position"
	const team:StringName = &"team"
	const attack_priorities:StringName = &"attack_priorities"
	const currently_attacking:StringName = &"currently_attacking"
	
var enemy_teams_info:EnemyTeams:
	get:
		return get_value(Keys.enemy_teams_info)
	set(value):
		set_value(Keys.enemy_teams_info, value)

var currently_attacking:Array[Unit]:
	get:
		return get_value(Keys.currently_attacking, [] as Array[Unit])
	set(value):
		set_value(Keys.currently_attacking, value)
		on_attacking_units_changed.emit()
		
var attack_priorities:Array[Unit]:
	get:
		return get_value(Keys.attack_priorities, [] as Array[Unit])
	set(value):
		set_value(Keys.attack_priorities, value)
		on_attacking_priorities_changed.emit()
		
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
