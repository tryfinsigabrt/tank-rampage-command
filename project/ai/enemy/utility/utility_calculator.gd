class_name UtilityCalculator extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

const ATTACK_BEHAVIOR:UtilityAIBehavior = preload("uid://78xpbsfwlfdd")
const FLEE_BEHAVIOR:UtilityAIBehavior = preload("uid://budmbddpy0ywh")

var _enemy_action_context:EnemyActionContext
var _all_options:Array[UtilityAIOption]

func _ready() -> void:
	_enemy_action_context = EnemyActionContext.new()
	_enemy_action_context.blackboard = blackboard
	
	_all_options = [
		UtilityAIOption.new(ATTACK_BEHAVIOR, _enemy_action_context, _attack),
		UtilityAIOption.new(FLEE_BEHAVIOR, _enemy_action_context, _flee)
		# Explore is the default currently for remaining units
	]

func assess_threats() -> void:
	# TODO: Simplest strategy
	var enemy_teams: EnemyTeams  = blackboard.enemy_teams_info
	var focus_position:Vector3 = blackboard.focus_position
	
	var attack_priorities:Array[Unit]
	
	for team:EnemyTeamUnits in enemy_teams.all_teams():
		var threat_units := team.get_visible_threat_units(focus_position)
		if threat_units:
			for unit_score in threat_units:
				attack_priorities.push_back(unit_score.unit)
	
	if attack_priorities:
		print_debug("%s: Team %d attack priorities: %s" % [name, blackboard.team, attack_priorities])
	
	# TODO: For each threat calculate if should attack or flee
		
	blackboard.attack_priorities = attack_priorities
			
func _tick() -> void:
	pass # Replace with function body.


func _attack() -> void:
	pass

func _flee() -> void:
	pass
	
func _explore() -> void:
	pass
