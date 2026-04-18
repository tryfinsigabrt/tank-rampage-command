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
	@warning_ignore("missing_await")
	_evaluate_priorities()
	
func _evaluate_priorities() -> void:
	#print("EVALUATED at %.1f" % [GameManager.game_timer.time_seconds])
	var assessed:bool = await utility_calculator.assess_threats()
	if not assessed:
		return
		
	#Recalculate distilled threat clusters
	var distilled_threats := blackboard.threats
	distilled_threats.clear()
	
	for threat_context in utility_calculator.all_threat_contexts:
		distilled_threats.push_back(EnemyThreatContext.from_unit_threat_context(threat_context))
	
func _on_command_finished(unit:Unit, _command:StringName, _command_id:int, _args:Dictionary[StringName, Variant]) -> void:
	if not _is_on_our_team(unit):
		return
	
	# Wait to let command queue settle
	await get_tree().process_frame
	if unit.get_or_add_actions().is_idle():
		var available_units:Array[Unit] = blackboard.idle_units
		available_units.push_back(unit)
		blackboard.idle_units = available_units
		
		@warning_ignore("missing_await")
		_evaluate_priorities()

func _on_command_scheduled(unit:Unit, _command:StringName, _command_id:int, _args:Dictionary[StringName, Variant]) -> void:
	if not _is_on_our_team(unit):
		return
		
	var idle_units:Array[Unit] = blackboard.idle_units
	idle_units.erase(unit)
	blackboard.idle_units = idle_units
	
	@warning_ignore("missing_await")
	_evaluate_priorities()

func _is_on_our_team(unit:Unit) -> bool:
	var team_units:TeamUnits = blackboard.team_info
	return unit.is_on_team(team_units.team)

func _on_team_units_new_asset_built(asset: Node3D) -> void:
	var unit:Unit = asset as Unit
	if not unit:
		return
		
	# Mark as idle initially
	var idle_units:Array[Unit] = blackboard.idle_units
	idle_units.push_back(unit)
	blackboard.idle_units = idle_units
	await _evaluate_priorities()	


func _on_resource_discovered(resource: Node3D) -> void:
	var resource_id:int = resource.get_instance_id()
	var resources:PackedInt64Array = blackboard.active_resources
	if resource_id in resources:
		return
		
	resources.push_back(resource_id)
	
	# Re-evaluate after the resource is collected or disappears
	var assigned_resources: PackedInt64Array = blackboard.assigned_resources
	
	resource.tree_exited.connect(func() -> void:
		resources.erase(resource_id)
		assigned_resources.erase(resource_id)
		blackboard.on_available_resources_changed.emit()
	)

	blackboard.on_available_resources_changed.emit()
	
func _on_control_point_discovered(control_point: ControlPoint) -> void:
	var known_control_points := blackboard.control_points
	if control_point in known_control_points:
		return
		
	known_control_points.push_back(control_point)
	blackboard.on_control_point_discovered.emit(control_point)
