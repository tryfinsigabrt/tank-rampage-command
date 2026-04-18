class_name UtilityCalculator extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var threat_eval_tick: Timer = $Tick
@onready var rate_limiter: RateLimiter = $RateLimiter

const ATTACK_BEHAVIOR:UtilityAIBehavior = preload("uid://78xpbsfwlfdd")
const FLEE_BEHAVIOR:UtilityAIBehavior = preload("uid://budmbddpy0ywh")
const IGNORE_BEHAVIOR:UtilityAIBehavior = preload("uid://c1rakxqesi80y")

const ATTACK_BEHAVIOR_KEY:StringName = &"attack"
const FLEE_BEHAVIOR_KEY:StringName = &"flee"
const IGNORE_BEHAVIOR_KEY:StringName = &"ignore"

var _all_options:Array[UtilityAIOption]

var _unit_utilities:Dictionary[StringName, Array]
var all_threat_contexts:Array[UnitThreatContext]

func _ready() -> void:
	_all_options = [
		UtilityAIOption.new(ATTACK_BEHAVIOR, null, ATTACK_BEHAVIOR_KEY),
		UtilityAIOption.new(FLEE_BEHAVIOR, null, FLEE_BEHAVIOR_KEY),
		UtilityAIOption.new(IGNORE_BEHAVIOR, null, IGNORE_BEHAVIOR_KEY)
		# Explore is the default currently for remaining units
	]
	
	for option in _all_options:
		_unit_utilities[option.action] = [] as Array[Unit]

func assess_threats() -> bool:
	var should_reassess:bool = await rate_limiter.limit()
	if not should_reassess:
		#print("EVALUATE(RATE LIMIT) at %.1f" % [GameManager.game_timer.time_seconds])
		return false
	#print("EVALUATE(EXEC) at %.1f" % [GameManager.game_timer.time_seconds])

	# TODO: Add an option to collect the resource which takes into account the threats
	# This will be set as a resource collecting priority on the blackboard and be a separate action that
	# results in a move to the token position
	
	# or possibly this is a separate action
	# Reset the timer so that it cools down when called externally
	all_threat_contexts.clear()

	threat_eval_tick.start()
	
	var enemy_teams: EnemyTeams  = blackboard.enemy_teams_info
	_reset_unit_utilities()
	
	var our_units:Array[Unit] = blackboard.team_info.units
	
	var options := _all_options.duplicate()
	for team:EnemyTeamUnits in enemy_teams.all_teams():
		var contexts : Array[UnitThreatContext] = team.get_visible_threat_contexts(our_units)
		all_threat_contexts.append_array(contexts)
		
		for context in contexts:
			for option:UtilityAIOption in options:
				option.context = context
			
			var decision := UtilityAI.choose_highest(options)
			_unit_utilities[decision.action].append_array(context.threat_cluster.units)
			SignalBus.on_utility_calculation.emit(name, blackboard.team, options, decision)

	SignalBus.on_utility_calculation_complete.emit(name, blackboard.team)
	
	if OS.is_debug_build():
		for action in _unit_utilities:
			var action_units := _unit_utilities[action]
			if action_units:
				print_debug("%s: Team %d %s priorities(%d): %s" % [name, blackboard.team, action, action_units.size(), action_units])

	# Need to duplicate so that signals fire
	blackboard.attack_priorities = (_unit_utilities.get(ATTACK_BEHAVIOR_KEY) as Array[Unit]).duplicate()
	blackboard.avoidance_enemies = (_unit_utilities.get(FLEE_BEHAVIOR_KEY) as Array[Unit]).duplicate()
		
	_reset_unit_utilities()
	
	return true

func _reset_unit_utilities() -> void:
	for key in _unit_utilities:
		_unit_utilities[key].clear()
	
func _tick() -> void:
	# Only re-evaluate if there are any visible threats
	if not blackboard.visible_enemy_count:
		return
		
	await assess_threats()
