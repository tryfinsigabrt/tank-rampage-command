class_name AiUnitDirectives extends Node

const ComponentName:StringName = &"AiUnitDirectives"

const DEFEND_POSITION:StringName = &"defend_position"
const TIME:StringName = &"time"

#region Signals
@warning_ignore_start("unused_signal")
signal on_started(state:State)
signal on_completed(state:State)
signal on_canceled(state:State)
@warning_ignore_restore("unused_signal")

#endregion

enum StateActivity
{
	NONE,
	STARTED,
	COMPLETED,
	CANCELED
}

class State:
	var key:StringName
	var priority:float
	var data:Dictionary[StringName, Variant]
	var state:StateActivity
	
	func _to_string() -> String:
		return "%s:%d" % [key, priority]

var unit:Unit

var _requested_states:Array[State]
var _active_state:State
var _recent_commands:CircularBuffer

@export
var evaluation_delay:float = 0.1

@onready var _behavior_tree: BeehaveTree = %BeehaveTree
@onready var blackboard: UnitDirectiveBlackboard = %Blackboard
@onready var _priority_timer: Timer = %PriorityTimer

var enabled:bool:
	get: return _behavior_tree.enabled
	
#region States
func set_defend_position(position:Vector3, time:float) -> void:
	var state:State = State.new()
	state.key = DEFEND_POSITION
	state.data = {
		POSITION = position,
		TIME = time
	}
	
	_add_state(state)	
#endregion

func _add_state(state: State) -> void:
	# Highest priority goes last so can use "pop_back"
	var index:int = _requested_states.bsearch_custom(state, func(a:State, b:State) -> bool:
		return a.priority < b.priority
	)
	_requested_states.insert(index, state)
	
	_schedule_if_stopped()
	
func _ready() -> void:
	if not unit:
		push_error("%s: Added to a non-unit hierarchy!" % name)
		queue_free()
		return
		
	_recent_commands = CircularBuffer.new(10)
	_priority_timer.wait_time = evaluation_delay
	
	# Stop execution if another command issued outside the ecosystem
	unit.get_or_add_actions().command_issued.connect(_on_command_issued)
	
func _on_command_issued(command_id:int) -> void:
	# We issued this command
	if _recent_commands.contains(command_id):
		return
	print_debug("%s(%s): Unexpected command %d -> Canceling execution" % [name, unit.name, command_id])
	stop()
	
func start() -> void:
	print_debug("%s(%s): Start" % [name, unit.name])
	_schedule_next()

func stop() -> void:
	print_debug("%s(%s): Stop" % [name, unit.name])

	_priority_timer.stop()
	_behavior_tree.enabled = false
	
	if _active_state and _active_state.state == StateActivity.STARTED:
		_active_state.state = StateActivity.CANCELED
		on_canceled.emit(_active_state)
	_active_state = null
	blackboard.clear_state()
	
func notify_command(command_id:int) -> void:
	_recent_commands.add(command_id)
	
#region Component Registration
static func get_component(node: Node, required:bool = true) -> AiUnitDirectives:
	return Components.get_component(ComponentName, node, required) as AiUnitDirectives
		
func _enter_tree() -> void:
	unit = Groups.get_parent_with_type(self, Unit)
	if unit:
		Components.add_component(ComponentName, self, unit)

func _exit_tree() -> void:
	if unit:
		Components.remove_component(ComponentName, self, unit)
	if _active_state:
		on_canceled.emit(_active_state)
		_active_state = null
#endregion

func completed() -> void:
	var curr_state := _active_state
	if not curr_state:
		return
		
	curr_state.state = StateActivity.COMPLETED
	on_completed.emit(curr_state)
	
	if enabled:
		_schedule_next()

func canceled() -> void:
	var curr_state := _active_state
	if not curr_state:
		return
		
	curr_state.state = StateActivity.CANCELED
	on_canceled.emit(curr_state)
	
	if enabled:
		_schedule_next()
	
func started() -> void:
	var curr_state := _active_state
	if not curr_state:
		return
	
	_active_state.state = StateActivity.STARTED
	on_started.emit(curr_state)
	
func _schedule_next() -> void:
	_active_state = null
	 
	if _requested_states:
		_schedule_if_stopped()
	else:
		_behavior_tree.enabled = false

func _schedule_if_stopped() -> void:
	if _priority_timer.is_stopped():
		_priority_timer.start()

func _on_priority_timer_timeout() -> void:
	if not _requested_states:
		return
	
	print_debug("%s(%s): Evaluating priorities: %s" % [name, unit.name, _requested_states])	
	# Check if we should switch priorities
	var switch_state:bool = true
	
	if _active_state:
		var next_priority:State = _requested_states.back()
		if next_priority.priority <= _active_state.priority:
			switch_state = false
			
	if switch_state:
		_switch_state(_requested_states.pop_back())

func _switch_state(state:State) -> void:
	print_debug("%s(%s): Switching state to %s" % [name, unit.name, state])
	if not _behavior_tree.enabled:
		_behavior_tree.enabled = true
		
	_active_state = state
	blackboard.set_state(state)
