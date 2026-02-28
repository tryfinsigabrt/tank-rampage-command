class_name EnemyScanner extends Node

const max_unit_result_count:int = 256

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var unit_sweeper: UnitSweeper = $UnitSweeper

var _visible_enemies:PackedInt64Array
var _new_visible_enemies:PackedInt64Array
	
func _tick() -> void:
	var attention_center:Vector3 = blackboard.team_info.get_average_position()
	blackboard.focus_position = attention_center
	
	var enemy_data:EnemyTeams = blackboard.enemy_teams_info
	enemy_data.mark_all_not_visible()
	
	var enemies:Array[Unit] = unit_sweeper.sweep_units(attention_center, blackboard.team_info.units, blackboard.team)
	_new_visible_enemies.clear()
	
	if LogUtils.verbose:
		print_debug("%s: Team %d found %d enemies" % [name, blackboard.team, enemies.size()])
		
	for enemy in enemies:
		var team_info := enemy_data.get_team(enemy.team)
		if team_info:
			team_info.mark_seen(enemy)
			_new_visible_enemies.push_back(enemy.get_instance_id())
	_new_visible_enemies.sort()
	if _new_visible_enemies != _visible_enemies:
		_visible_enemies = _new_visible_enemies
		blackboard.on_unit_visibility_changed.emit()
		
