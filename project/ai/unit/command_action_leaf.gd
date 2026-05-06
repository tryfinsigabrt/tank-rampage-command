@tool
class_name CommandActionLeaf extends ActionLeaf

var my_action:StringName
var action_id:int

var _cleanup_record := CircularBuffer.new(10)

func before_run(actor: Node, blackboard: Blackboard) -> void:
	my_action = blackboard.get_value(UnitBlackboard.Keys.Action)
	action_id = blackboard.get_value(UnitBlackboard.Keys.ActionId)
	
	#print_debug("%s: CLEANUP %s - command %d -> %s BEFORE RUN" % [name, actor.name, action_id, my_action])

	SignalBus.on_unit_command_started.emit(actor as Unit, my_action, action_id, _get_action_args())
	
func interrupt(actor: Node, blackboard: Blackboard) -> void:
	super.interrupt(actor, blackboard)
	#print_debug("%s: CLEANUP %s - command %d -> %s interrupted" % [name, actor.name, action_id, my_action])
	#
	_check_and_do_cleanup(actor, blackboard)
	
func after_run(actor: Node, blackboard: Blackboard) -> void:
	_check_and_do_cleanup(actor, blackboard)
	
func _check_and_do_cleanup(actor: Node, blackboard: UnitBlackboard) -> void:
	if not _cleanup_record.contains(action_id):
		_cleanup_record.add(action_id)
		_cleanup(actor, blackboard)

func _cleanup(actor: Node, _blackboard: UnitBlackboard) -> void:
	SignalBus.on_unit_command_finished.emit(actor as Unit, my_action, action_id, _get_action_args())
	
func _check_running_state(blackboard: Blackboard) -> int:
	# TODO: Maybe consider using the ActionId as the comparison instead of the name as then it is clearly a new order
	# though we may have asked to do the equivalent thing a second time
	var current_action:StringName = blackboard.get_value(UnitBlackboard.Keys.Action, &"")
	if current_action != my_action:
		if LogUtils.debug:
			print_debug("%s: current_action=%s changed from %s" % [name, current_action, my_action])
		return FAILURE
	return RUNNING if _should_continue_running(blackboard) else FAILURE
	
func _should_continue_running(_blackboard: Blackboard) -> bool:
	return true
	
func _get_action_args() -> Dictionary[StringName, Variant]:
	return {}
