@tool
class_name UnitCommandDecorator extends Decorator

var my_action:StringName
var action_id:int
var command_args:Dictionary[StringName, Variant]

var _cleanup_record := CircularBuffer.new(10)

func before_run(actor: Node, blackboard: Blackboard) -> void:
	my_action = blackboard.get_value(UnitBlackboard.Keys.Action)
	action_id = blackboard.get_value(UnitBlackboard.Keys.ActionId)
	command_args = blackboard.get_value(UnitBlackboard.Keys.CommandArgs)
	
	SignalBus.on_unit_command_started.emit(actor as Unit, my_action, action_id, command_args)
	
	super(actor, blackboard)
	
func interrupt(actor: Node, blackboard: Blackboard) -> void:
	super(actor, blackboard)	#
	_check_and_do_cleanup(actor, blackboard)
	
func after_run(actor: Node, blackboard: Blackboard) -> void:
	_check_and_do_cleanup(actor, blackboard)
	super(actor, blackboard)
	
func tick(actor: Node, blackboard: Blackboard) -> int:	
	var response:int = _check_running_state(blackboard)
	
	if response == RUNNING:
		var c: BeehaveNode = get_child(0)

		if c != running_child:
			c.before_run(actor, blackboard)

		response = c._safe_tick(actor, blackboard)
		if can_send_message(blackboard):
			BeehaveDebuggerMessages.process_tick(c.get_instance_id(), response, blackboard.get_debug_data())

		if c is ConditionLeaf:
			blackboard.set_value("last_condition", c, str(actor.get_instance_id()))
			blackboard.set_value("last_condition_status", response, str(actor.get_instance_id()))

		if response == RUNNING:
			running_child = c
			if c is ActionLeaf:
				blackboard.set_value("running_action", c, str(actor.get_instance_id()))
			return RUNNING
		else:
			c.after_run(actor, blackboard)
			_cleanup_running(c, actor, blackboard)
			return response
	else:
		interrupt(actor, blackboard)
		_cleanup_running(running_child, actor, blackboard)
		return response
		
func _check_and_do_cleanup(actor: Node, blackboard: UnitBlackboard) -> void:
	if not _cleanup_record.contains(action_id):
		_cleanup_record.add(action_id)
		_cleanup(actor, blackboard)

## Copied from Composite. Notice that decorators set the running action but don't clean it up like Composites do which is a bit inconsistent
func _cleanup_running(child: Node, actor: Node, blackboard: Blackboard) -> void:
	if child and child == running_child:
		var id := str(actor.get_instance_id())
		if child == blackboard.get_value("running_action", null, id):
			blackboard.set_value("running_action", null, id)
			
func _check_running_state(blackboard: Blackboard) -> int:
	if get_child_count() == 0:
		return FAILURE
		
	var current_action:StringName = blackboard.get_value(UnitBlackboard.Keys.Action, &"")
	if current_action != my_action:
		if LogUtils.debug:
			print_debug("%s: current_action=%s changed from %s" % [name, current_action, my_action])
		return FAILURE
	return RUNNING if _should_continue_running(blackboard) else FAILURE
	
#region Hook Methods
func _cleanup(actor: Node, _blackboard: UnitBlackboard) -> void:
	SignalBus.on_unit_command_finished.emit(actor as Unit, my_action, action_id, command_args)
	
func _should_continue_running(_blackboard: Blackboard) -> bool:
	return true
	
#endregion
