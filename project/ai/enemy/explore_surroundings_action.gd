@tool
extends ActionLeaf

@export
var move_radius:Vector2 = Vector2(100, 500)

@export
var heading_variation_degrees:Vector2 = Vector2(30,120)

# Units available for moving
var _available_units:Dictionary[int, bool] = {}
# all unit mappings
var _unit_mapping:Dictionary[int, Unit] = {}

func before_run(_actor: Node, in_blackboard: Blackboard) -> void:
	# Sync up all our data
	_clear()
	
	SignalBus.on_unit_command_finished.connect(_on_command_finished)
	
	var blackboard: EnemyTeamBlackboard = in_blackboard
	
	var our_team:TeamUnits = blackboard.team_info
	var our_units:Array[Unit] = our_team.units
	for unit in our_units:
		var id:int = unit.get_instance_id()
		_unit_mapping[id] = unit
		_available_units[id] = true
	
	# TODO: Listen for newly built units and move this to blackboard
	
func after_run(_actor: Node, _blackboard: Blackboard) -> void:
	_clear()
	
func tick(_actor: Node, _blackboard: Blackboard) -> int:
	if not _unit_mapping:
		print_debug("%s: Pre-condition failure: No units" % name)
		return FAILURE		
	
	for unit_id in _available_units:
		var unit:Unit = _unit_mapping.get(unit_id)
		if unit:
			_select_move_target(unit)
			
	_available_units.clear()
		
	return RUNNING
	
	# TODO: SUCCESS condition?
	
func _select_move_target(unit:Unit) -> void:
	var pos:Vector3 = unit.global_position
	var heading:Vector3 = unit.global_forward
	
	var distance:float = randf_range(move_radius.x, move_radius.y)
	var heading_deviation_deg:float = randf_range(heading_variation_degrees.x, heading_variation_degrees.y)
	
	var new_heading:Vector3 = heading.rotated(Vector3.UP, deg_to_rad(heading_deviation_deg))
	
	var target_pos:Vector3 = pos + new_heading * distance
	unit.get_or_add_actions().move(target_pos)
	
func _clear() -> void:
	_unit_mapping.clear()
	_available_units.clear()
	if SignalBus.on_unit_command_finished.is_connected(_on_command_finished):
		SignalBus.on_unit_command_finished.disconnect(_on_command_finished)

func _on_command_finished(unit:Unit, command:StringName) -> void:
	if command == UnitBlackboard.Action.Move:
		var id:int = unit.get_instance_id()
		_available_units[id] = true
		# FIXME: Need a way to retrieve the target that was being attacked - it needs to be part of the signal so we can erase ourselves from _currently_attacknig_mapping
