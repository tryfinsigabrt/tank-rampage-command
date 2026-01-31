extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

func _on_unit_visibility_changed() -> void:
	# TODO: Simplest strategy
	var enemy_teams: EnemyTeams  = blackboard.enemy_teams_info
	var focus_position:Vector3 = blackboard.focus_position
	
	var attack_priorities:Array[Unit]
	
	for team:EnemyTeamUnits in enemy_teams.all_teams():
		var closest_visible_unit := team.get_closest_visible_unit(focus_position)
		if closest_visible_unit:
			attack_priorities.push_back(closest_visible_unit)
	
	blackboard.attack_priorities = attack_priorities
