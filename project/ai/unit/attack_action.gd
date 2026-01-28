@tool
extends ActionLeaf

var _unit:Unit
var _targeted_unit:Unit
var _finished:int = 0
var _attack_action:AttackAction

# TODO: Intermediate refactoring step
const attack_action_scene = preload("uid://cwj8iaowhbop5")

func interrupt(actor: Node, blackboard: Blackboard) -> void:
	if is_instance_valid(_attack_action):
		_attack_action.queue_free()
	super.interrupt(actor, blackboard)

func before_run(actor: Node, blackboard: Blackboard) -> void:
	_unit = actor as Unit
	_targeted_unit = blackboard.get_value(UnitBlackboard.Keys.TargetUnit) as Unit
	if not _unit or not _targeted_unit:
		_finished = -1
		push_error("%s: Missing unit or targeted unit - cannot perform attack action" % name)
		return

	_attack_action = attack_action_scene.instantiate()
	_attack_action.controlled_unit = _unit
	_attack_action.targeted_unit = _targeted_unit
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(_targeted_unit.global_position, 10.0, Color.RED, 3.0)
	
	_attack_action.tree_exited.connect(func() -> void:
		_finished = 1
	)

	add_child(_attack_action)

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	match _finished:
		0:
			return RUNNING
		1:
			return SUCCESS
		_:
			return FAILURE
