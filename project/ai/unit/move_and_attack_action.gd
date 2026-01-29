@tool
extends CommandActionLeaf

var _unit:Unit
var _target_position:Vector3
var _finished:int = 0
var _attack_action:AttackAction

# TODO: Intermediate refactoring step
const attack_action_scene = preload("uid://cwj8iaowhbop5")

func after_run(_actor: Node, _blackboard: Blackboard) -> void:
	if is_instance_valid(_attack_action):
		_attack_action.queue_free()
	
func before_run(actor: Node, blackboard: Blackboard) -> void:
	super.before_run(actor, blackboard)
	
	_finished = 0
	_unit = actor as Unit
	_target_position = blackboard.get_value(UnitBlackboard.Keys.TargetPosition) as Vector3
	if not _unit:
		_finished = -1
		push_error("%s: Missing current unit - cannot perform attack action" % name)
		return

	_attack_action = attack_action_scene.instantiate()
	_attack_action.controlled_unit = _unit
	_attack_action.targeted_location = _target_position
	
	# TODO: Only attack threats while moving
	# Right now just attacking the location itself repeatedly
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(_target_position, 5.0, Color.ORANGE, 3.0)
		
	_attack_action.tree_exited.connect(func() -> void:
		_finished = 1
	)

	add_child(_attack_action)

func tick(_actor: Node, blackboard: Blackboard) -> int:
	match _finished:
		0:
			return _check_running_state(blackboard)
		1:
			return SUCCESS
		_:
			return FAILURE

func _should_continue_running(blackboard: Blackboard) -> bool:
	var current_target:Vector3 = blackboard.get_value(UnitBlackboard.Keys.TargetPosition) as Vector3
	return current_target.is_equal_approx(_target_position)
