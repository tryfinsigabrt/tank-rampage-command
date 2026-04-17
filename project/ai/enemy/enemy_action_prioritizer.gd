extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var utility_calculator: UtilityCalculator = $UtilityCalculator
@onready var rate_limiter: RateLimiter = $RateLimiter

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
	var should_reassess:bool = await rate_limiter.limit()
	if should_reassess:
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
		
		@warning_ignore("missing_await")
		_evaluate_priorities()

func _on_command_scheduled(unit:Unit, _command:StringName, _args:Dictionary[StringName, Variant]) -> void:
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
	resource.tree_exited.connect(func() -> void:
		resources.erase(resource_id)
		@warning_ignore("missing_await")
		_evaluate_priorities()
	)
	
	@warning_ignore("missing_await")
	_evaluate_priorities()
