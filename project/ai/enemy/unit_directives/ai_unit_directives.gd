class_name AiUnitDirectives extends Node

const ComponentName:StringName = &"AiUnitDirectives"

#region State Keys
const DEFEND_POSITION:StringName = &"defend_position"
const DEFEND_AREA:StringName = &"defend_area"
const SECURE_CONTROL_POINT:StringName = &"secure_control_point"
const ATTACK_TARGET:StringName = &"attack_target"
const LOAD_INTO_TARGET_AND_WAIT:StringName = &"load_into_target_and_wait"
const LOAD_UNITS_AND_MOVE_TO_POSITION:StringName = &"load_units_and_move_to"
const EXPLORE_LOCATION = &"explore_location"
const FOLLOW_EXPLORER = &"follow_explorer"
const FLEE = &"flee"

#endregion

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
	var id:int
	var key:StringName
	var tag:String
	var priority:float
	var data:Dictionary[StringName, Variant]
	var state:StateActivity
	var is_equal:Callable
	
	var running:bool:
		get:
			return state == StateActivity.STARTED
			
	var active:bool:
		get:
			return state != StateActivity.COMPLETED and state != StateActivity.CANCELED
	
	var dormant:bool:
		get:
			return state == StateActivity.NONE
	
	var inactive:bool:
		get:
			return not active
			
	@warning_ignore("unused_signal")
	signal started
	@warning_ignore("unused_signal")
	signal finished(success:bool)
	
	func replace(previous_instance:State) -> State:
		id = previous_instance.id
		return self
		
	func _to_string() -> String:
		return "%s:%d" % [key, priority]
		
	func equals(other:State) -> bool:
		if not other:
			return false
		if key != other.key:
			return false
		# Invoke state-specific equality condition
		return is_equal.call(other.data)
	
	func wait_for_start() -> void:
		if state == StateActivity.NONE:
			await started
	
	func wait_for_completion() -> void:
		if active:
			await finished
					
var unit:Unit

var _requested_states:Array[State]
var _active_state:State
var _recent_commands:CircularBuffer

@export
var evaluation_delay:float = 0.1

@export
var control_point_radius_defend_fraction:float = 0.5

@export var _behavior_tree: BeehaveTree
@onready var blackboard: UnitDirectiveBlackboard = %Blackboard
@onready var _priority_timer: Timer = %PriorityTimer

var _state_id_counter:int

var enabled:bool:
	get: return _behavior_tree.enabled
	
var desired_position:Vector3:
	get:
		if not enabled or not _active_state:
			return Vector3.INF
		var data := _active_state.data
		return data.get(UnitDirectiveBlackboard.Keys.Position, Vector3.INF)

var active_state:State:
	get:
		return _active_state
			
#region States
func set_defend_position(position:Vector3, time:float, priority:int = 0, tag:String = "") -> State:
	var state:State = State.new()
	state.key = DEFEND_POSITION
	state.priority = priority
	state.tag = tag
	state.data = {
		POSITION = position,
		TIME = time
	}
	
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		var other_pos:Vector3 = other_data[&"POSITION"]
		return other_pos.distance_squared_to(position) < 25.0
	
	_add_or_update_state(state)
	
	return state

func set_defend_area(area:BoundingSphere, time:float, position_callback:Callable, priority:int = 0, tag:String = "") -> State:
	return _set_defend_area_key(area, time, position_callback, DEFEND_AREA, priority, tag)

func set_defend_control_point(control_point:ControlPoint, time:float, priority:int = 0, tag:String = "") -> State:
	# Bounds were computed once before in control_point_prioritizer.gd but the AABB is already computed so its cheap to reconstruct it on each directive issuance
	var control_bounds: Bounds = Bounds.new(control_point.get_global_bounds(), Bounds.Type.SPHERE_INSCRIBED)
	var countrol_bounding_sphere:BoundingSphere = control_bounds.inscribed_sphere
	
	# If we are a ranged unit then pick a position where we can cover the area
	var position_callback: Callable = func() -> Vector3:
		var weapon:Weapon = unit.weapon
		var ranged_weapon:bool = not weapon.prefer_close_shots if weapon else false
		var defense_position:Vector3
		var defense_radius: float = countrol_bounding_sphere.radius * control_point_radius_defend_fraction
		
		if ranged_weapon:
			var pos:Vector3 = unit.global_position
			var ideal_defense_distance:float = MathUtils.mid_point(weapon.ideal_fire_range)
			var max_target_point:Vector3 = countrol_bounding_sphere.furthest_point_to(pos)
			var to_pos_dir:Vector3 = countrol_bounding_sphere.center.direction_to(pos)
			defense_position = max_target_point + to_pos_dir * ideal_defense_distance
		else:
			defense_position = countrol_bounding_sphere.center
		
		# Calculate a random point near the center of the control point
		var defend_pos_2d:Vector2 = MathUtils.get_random_point_in_circle(defense_radius)
		defense_position +=  Vector3(defend_pos_2d.x, 0.0, defend_pos_2d.y)
		return defense_position
	
	# Also add the control point for context	
	var state:State = State.new()
	state.key = SECURE_CONTROL_POINT
	state.priority = priority
	state.tag = tag
	state.data = {
		BOUNDS = countrol_bounding_sphere,
		TIME = time,
		POSITION_CALLBACK = position_callback,
		CONTROL_POINT = control_point,
	}
	
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		var other_cp:ControlPoint = other_data[&"CONTROL_POINT"]
		return control_point == other_cp
	
	_add_or_update_state(state)
	
	return state
		
func _set_defend_area_key(area:BoundingSphere, time:float, position_callback:Callable, key:StringName, priority:int = 0, tag:String = "") -> State:
	var state:State = State.new()
	state.key = key
	state.priority = priority
	state.tag = tag
	state.data = {
		BOUNDS = area,
		TIME = time,
		POSITION_CALLBACK = position_callback,
	}
	
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		var other_bounds:BoundingSphere = other_data[&"BOUNDS"]
		return area.is_equal_approx(other_bounds)
	
	_add_or_update_state(state)
	
	return state

func set_attack_target(target:Node3D, priority:int = 0, tag:String = "") -> State:
	# Set container bounding radius to be weapon range
	var target_bounds:BoundingSphere = null
	var weapon:Weapon = unit.weapon
	if weapon:
		# Use max distance range since the bunker gives a boost in range
		var radius:float = weapon.max_distance_range.y
		target_bounds = BoundingSphere.new(target.global_position, radius)
		
	var state:State = State.new()
	state.key = ATTACK_TARGET
	state.priority = priority
	state.tag = tag
	state.data = {
		TARGET_NODE = target,
		BOUNDS = target_bounds,
	}
	
	var target_id:int = target.get_instance_id()
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		if not is_instance_id_valid(target_id):
			return false
			
		var other_target:Variant = other_data[&"TARGET_NODE"]
		return is_instance_valid(other_target) and target_id == other_target.get_instance_id()
	
	_add_or_update_state(state)
	
	return state

func set_lead_explore_location(followers:Array[Unit], target:Vector3, priority:int = 0, tag:String = "") -> State:
	var nav := GameUnitNavigation.get_component(unit)
	var target_radius:float = nav.distance_threshold * 2.0 if nav else 10.0
	var bounds := BoundingSphere.new(target, target_radius)
	
	var unit_ids:PackedInt64Array
	unit_ids.resize(followers.size())
	for i in followers.size():
		unit_ids.push_back(followers[i].get_instance_id())
	unit_ids.sort()
	
	var state:State = State.new()
	state.key = EXPLORE_LOCATION
	state.priority = priority
	state.tag = tag
	state.data = {
		(UnitDirectiveBlackboard.Keys.Position) : target,
		(UnitDirectiveBlackboard.Keys.BOUNDS) : bounds,
		(UnitDirectiveBlackboard.Keys.LoadUnits) : unit_ids
	}
	
	var is_container:bool = UnitContainerComponent.has_component(unit)
	
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		# As long as we are the explorer just keep replacing the state, unless we are a transport and then the unit ids need to match
		if is_container:
			return true
		
		return unit_ids == other_data[UnitDirectiveBlackboard.Keys.LoadUnits]
	
	_add_or_update_state(state)
	
	return state

func set_follow_explorer(explorer:Unit, explorer_state:State, priority:int = 0, tag:String = "") -> State:
	var state:State = State.new()
	state.key = FOLLOW_EXPLORER
	state.priority = priority
	state.tag = tag
	state.data = {
		(UnitDirectiveBlackboard.Keys.TargetNode) : explorer,
		(UnitDirectiveBlackboard.Keys.TargetState) : explorer_state,
	}
	
	var explorer_id:int = explorer.get_instance_id()
	
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		var other_state:State = other_data[UnitDirectiveBlackboard.Keys.TargetState]
		if other_state != explorer_state:
			return false
		var other_explorer:Unit = other_data[UnitDirectiveBlackboard.Keys.TargetNode]
		return other_explorer and explorer_id == other_explorer.get_instance_id()
		
	_add_or_update_state(state)
	
	return state

func set_flee(target_location:Vector3, priority:int = 0, tag:String = "") -> State:
	var state:State = State.new()
	state.key = FLEE
	state.priority = priority
	state.tag = tag
	state.data = {
		(UnitDirectiveBlackboard.Keys.Position) : target_location,
	}
		
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		var other_pos:Vector3 = other_data[&"POSITION"]
		return other_pos.is_equal_approx(target_location)
		
	_add_or_update_state(state)
	
	return state
		
#endregion
	
#region Future Work States
# TODO: These probably aren't needed and covered by follow/lead states
## Load into the give target container and wait for it to unload
func set_load_into_target_and_wait(target:Node3D, priority:int = 0, tag:String = "") -> State:
	var state:State = State.new()
	state.key = LOAD_INTO_TARGET_AND_WAIT
	state.priority = priority
	state.tag = tag
	state.data = {
		ASSET_LOAD = target,
	}
	
	var target_id:int = target.get_instance_id()
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		if not is_instance_id_valid(target_id):
			return false
			
		var other_target:Variant = other_data[&"TARGET_NODE"]
		return is_instance_valid(other_target) and target_id == other_target.get_instance_id()
	
	# TODO: Create directive state
	#_add_or_update_state(state)
	# return state
	return null

## Used by transports to optimally load the given units (moving toward them to close gap)
## and then head to the given target and then unload once at the target
# Ideally it should change its heading and flee if under attack and far from destination
func set_load_units_and_move_to_with_unload(units:Array[Unit], target:Vector3, priority:int = 0, tag:String = "") -> State:
	var unit_ids:PackedInt64Array
	unit_ids.resize(units.size())
	for i in units.size():
		unit_ids.push_back(units[i].get_instance_id())
	unit_ids.sort()
	
	var state:State = State.new()
	state.key = LOAD_UNITS_AND_MOVE_TO_POSITION
	state.priority = priority
	state.tag = tag
	state.data = {
		POSITION = target,
		LOAD_UNITS = unit_ids
	}
	
	state.is_equal = func(other_data:Dictionary[StringName, Variant]) -> bool:
		return unit_ids == other_data[UnitDirectiveBlackboard.Keys.LoadUnits]
	
	# TODO: Create directive state
	#_add_or_update_state(state)
	# return state
	return null

#endregion

#region Public API

func has_active_state(matcher:Callable) -> bool:
	return _active_state and matcher.call(_active_state)
	
func has_state(matcher:Callable) -> bool:
	if has_active_state(matcher):
		return true
		
	for state in _requested_states:
		if matcher.call(state):
			return true
	return false
	
func start() -> void:
	print_debug("%s(%s): Start" % [name, unit.name])
	_schedule_next()

func stop() -> void:
	print_debug("%s(%s): Stop" % [name, unit.name])

	_priority_timer.stop()
	_behavior_tree.enabled = false
	
	var unit_actions := unit.get_or_add_actions()
	if unit_actions.command_issued.is_connected(_on_command_issued):
		unit_actions.command_issued.disconnect(_on_command_issued)	
	
	if _active_state and _active_state.state == StateActivity.STARTED:
		_active_state.state = StateActivity.CANCELED
		on_canceled.emit(_active_state)
	_active_state = null
	blackboard.clear_state()
	
func notify_command(command_id:int) -> void:
	_recent_commands.add(command_id)

func completed() -> void:
	var curr_state := _active_state
	if not curr_state:
		return
		
	curr_state.state = StateActivity.COMPLETED
	on_completed.emit(curr_state)
	curr_state.finished.emit(true)

	if enabled:
		_schedule_next()

func canceled() -> void:
	var curr_state := _active_state
	if not curr_state:
		return
		
	curr_state.state = StateActivity.CANCELED
	curr_state.finished.emit(false)
	on_canceled.emit(curr_state)
	
	if enabled:
		_schedule_next()
	
func started() -> void:
	var curr_state := _active_state
	if not curr_state:
		return
	
	_active_state.state = StateActivity.STARTED
	curr_state.started.emit()
	on_started.emit(curr_state)

#endregion

#region Component Registration
static func get_component(node: Node, required:bool = true) -> AiUnitDirectives:
	return Components.get_component(ComponentName, node, required) as AiUnitDirectives
		
func _enter_tree() -> void:
	unit = Groups.get_parent_with_type(self, Unit)
	if unit:
		Components.add_component(ComponentName, self, unit)
		_behavior_tree.name = "AIUnitDirectives-t%d-%s" % [unit.team, unit.name]

func _exit_tree() -> void:
	if unit:
		Components.remove_component(ComponentName, self, unit)
	if _active_state:
		on_canceled.emit(_active_state)
		_active_state = null
#endregion

#region lifecycle hooks
func _ready() -> void:
	if not unit:
		push_error("%s: Added to a non-unit hierarchy!" % name)
		queue_free()
		return
		
	_recent_commands = CircularBuffer.new(10)
	_priority_timer.wait_time = evaluation_delay
	
#endregion

#region private methods
func _add_or_update_state(state: State) -> void:
	# If the key exists already, update in place
	if _active_state and _active_state.equals(state):
		_active_state = state.replace(_active_state)
	else:
		var existing_index:int = -1
		for i in _requested_states.size():
			var existing_state:State = _requested_states[i]
			if existing_state.equals(state):
				existing_index = i
				break
		if existing_index != -1:
			var existing_state:State = _requested_states[existing_index]
			_requested_states[existing_index] = state.replace(existing_state)
			# If not same priority, then have to do full resort
			if not is_equal_approx(state.priority, existing_state.priority):
				_requested_states.sort_custom(_priority_compare)
		# Adding a new state, place at right location in priority queue
		else:
			_state_id_counter += 1
			state.id = _state_id_counter
			var index:int = _requested_states.bsearch_custom(state, _priority_compare)
			_requested_states.insert(index, state)
			
	# Reschedule if top priority changed
	if not _active_state or (_requested_states and _active_state.priority < _requested_states.back().priority):
		_schedule_if_stopped()
	
# Highest priority goes last so can use "pop_back"
static func _priority_compare(a:State, b:State) -> bool:
	return a.priority < b.priority
	
func _on_command_issued(command_id:int) -> void:
	# We issued this command
	if _recent_commands.contains(command_id):
		return
	print_debug("%s(%s): Unexpected command %d -> Canceling execution" % [name, unit.name, command_id])
	stop()
		
func _schedule_next() -> void:
	_active_state = null
	 
	if _requested_states:
		_schedule_if_stopped()
	else:
		_behavior_tree.enabled = false

func _schedule_if_stopped() -> void:
	if _priority_timer.is_stopped():
		_priority_timer.start()


func _switch_state(state:State) -> void:
	print_debug("%s(%s): Switching state to %s" % [name, unit.name, state])
	if not _behavior_tree.enabled:
		_behavior_tree.enabled = true
		# Stop execution if another command issued outside the ecosystem
		var unit_actions := unit.get_or_add_actions()
		if not unit_actions.command_issued.is_connected(_on_command_issued):
			unit_actions.command_issued.connect(_on_command_issued)	
		
	_active_state = state
	blackboard.set_state(state)
	
#endregion

#region Scene Signal Connections
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

#endregion
