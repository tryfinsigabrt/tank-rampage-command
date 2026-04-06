@tool
extends CommandActionLeaf

var _unit:Unit

var _targeted_node:Node3D
var _targeted_position:Vector3 = Vector3.INF

var _finished:int = 0
var _attack_action:AttackAction

const attack_action_scene = preload("uid://cwj8iaowhbop5")

func after_run(_actor: Node, blackboard: Blackboard) -> void:
	if is_instance_valid(_attack_action):
		_attack_action.queue_free()
		_attack_action = null
		
	# Erase current target if it is invalid or if was the current target since there is no new target
	var current_target:Unit = blackboard.get_value(UnitBlackboard.Keys.TargetNode) as Unit
	var current_position:Vector3 = blackboard.get_value(UnitBlackboard.Keys.TargetPosition, -Vector3.INF)
	
	if not is_instance_valid(current_target) or current_target == _targeted_node:
		blackboard.erase_value(UnitBlackboard.Keys.TargetNode)
	if current_position.is_equal_approx(_targeted_position):
		blackboard.erase_value(UnitBlackboard.Keys.TargetPosition)
	
func before_run(actor: Node, blackboard: Blackboard) -> void:
	super.before_run(actor, blackboard)
	
	_finished = 0
	var valid:bool = false
	
	_unit = actor as Unit
	if _unit:
		_targeted_node = blackboard.get_value(UnitBlackboard.Keys.TargetNode) as Node3D
		if _targeted_node:
			valid = true
		elif blackboard.has_value(UnitBlackboard.Keys.TargetPosition):
			_targeted_position = blackboard.get_value(UnitBlackboard.Keys.TargetPosition)
			valid = true
		
	if not valid:
		_finished = -1
		push_error("%s: Missing unit or targeted unit/position - cannot perform attack action" % name)
		return

	_attack_action = attack_action_scene.instantiate()
	_attack_action.controlled_unit = _unit
	if _targeted_node:
		_attack_action.targeted_node = _targeted_node
	else:
		_attack_action.targeted_location = _targeted_position
	
	# Determine if we should prefer getting close or only move if out of range
	# Some weapons like the artillery shells prefer to stay at a distance
	var weapon:Weapon = _unit.weapon
	if weapon:
		_attack_action.move_into_range = AttackAction.MoveBehavior.ALWAYS \
			if weapon.prefer_close_shots else AttackAction.MoveBehavior.IF_OUT_RANGE
		
	if OS.is_debug_build() and not GameManager.is_owned_by_player(self):
		var pos:Vector3 = _targeted_node.global_position if _targeted_node else _targeted_position
		DebugDraw3D.draw_sphere(pos, 10.0, Color.RED, 3.0)
	
	_attack_action.tree_exited.connect(func() -> void:
		_finished = 1
	)

	add_child(_attack_action)

func tick(_actor: Node, blackboard: Blackboard) -> int:
	var result:int
	match _finished:
		0:
			result = _check_running_state(blackboard)
		1:
			result = SUCCESS
		_:
			result = FAILURE
			
	if result != RUNNING:
		SignalBus.on_unit_command_finished.emit(_unit, my_action, _get_action_args())
	return result
	
func _should_continue_running(blackboard: Blackboard) -> bool:
	var current_target_node:Node3D = blackboard.get_value(UnitBlackboard.Keys.TargetNode) as Node3D
	var current_targeted_position:Vector3 = blackboard.get_value(UnitBlackboard.Keys.TargetPosition, Vector3.INF)
	
	return current_target_node == _targeted_node and current_targeted_position.is_equal_approx(_targeted_position)

func _get_action_args() -> Dictionary[StringName, Variant]:
	return {
		&"target": _targeted_node
	}
