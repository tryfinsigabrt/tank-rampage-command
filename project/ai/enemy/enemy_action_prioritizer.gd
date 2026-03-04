extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var utility_calculator: UtilityCalculator = $UtilityCalculator

func _ready() -> void:
	SignalBus.on_unit_command_scheduled.connect(_on_command_scheduled)
	SignalBus.on_unit_command_finished.connect(_on_command_finished)

func _on_team_units_initialized(source: TeamUnits) -> void:
	# All units initially idle
	blackboard.idle_units = source.units.duplicate()
	
func _on_unit_visibility_changed() -> void:
	_evaluate_priorities()
	
func _evaluate_priorities() -> void:
	utility_calculator.assess_threats()
	
func _on_command_finished(unit:Unit, _command:StringName, _args:Dictionary[StringName, Variant]) -> void:
	if not _is_on_our_team(unit):
		return
	
	# Wait to let command queue settle
	await get_tree().process_frame
	if unit.get_or_add_actions().is_idle():
		var available_units:Array[Unit] = blackboard.idle_units
		available_units.push_back(unit)
		blackboard.idle_units = available_units
		_evaluate_priorities()

func _on_command_scheduled(unit:Unit, _command:StringName, _args:Dictionary[StringName, Variant]) -> void:
	if not _is_on_our_team(unit):
		return
		
	var idle_units:Array[Unit] = blackboard.idle_units
	idle_units.erase(unit)
	blackboard.idle_units = idle_units
	_evaluate_priorities()

func _is_on_our_team(unit:Unit) -> bool:
	var team_units:TeamUnits = blackboard.team_info
	return unit.is_on_team(team_units.team)
