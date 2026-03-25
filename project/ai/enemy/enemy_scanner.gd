class_name EnemyScanner extends Node

const max_unit_result_count:int = 256

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var unit_sweeper: UnitSweeper = $UnitSweeper
@onready var enemy_visibility_manager: EnemyVisibilityManager = $EnemyVisibilityManager

var _visible_enemies:PackedInt64Array
var _new_visible_enemies:PackedInt64Array
		
func _tick() -> void:
	var attention_center:Vector3 = blackboard.team_info.get_average_position()
	blackboard.focus_position = attention_center
	
	var enemy_data:EnemyTeams = blackboard.enemy_teams_info
	enemy_data.mark_all_not_visible()
	
	var enemies:Array[Unit]
	
	if GameManager.fog_of_war:
		enemies = enemy_visibility_manager.visible_units
	else:
		enemies = _sweep_for_enemies(attention_center)
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
		
func _sweep_for_enemies(attention_center:Vector3) -> Array[Unit]:
	var enemies:Array[Node3D] = unit_sweeper.sweep_assets(attention_center, blackboard.team_info.units, blackboard.team)
	
	if LogUtils.verbose:
		print_debug("%s: Team %d found %d enemies" % [name, blackboard.team, enemies.size()])
	
	# TODO: For now limiting to enemy units and all enemies will be units so just copy the array
	var enemy_units: Array[Unit]
	enemy_units.append_array(enemies)
	return enemy_units
