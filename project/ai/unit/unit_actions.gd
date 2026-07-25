class_name UnitActions extends Node3D

signal command_issued(command_id:int)
signal command_finished(command_id:int)

# Change to @export and not onready as we need to rename it for clarity in the Beehave debugger
@export var behavior_tree: BeehaveTree

@onready var blackboard: UnitBlackboard = $Blackboard
@onready var idle_state: IdleUnitState = $IdleState

@export
var unit:Unit

var _unit_nav:GameUnitNavigation
var _initial_stuck_detection:bool

var _command_counter:int

var _command_id:int

var _move_tracker:MoveTracker

var last_command_id:int:
	get:
		return _command_id

func _enter_tree() -> void:
	if unit:
		behavior_tree.name = "UnitActions-t%d-%s" % [unit.team, unit.name]

@export
var enabled:bool:
	set(value):
		enabled = value
		_update_tree_state()
	get:
		return enabled
	
## Minimum distance to maintain when following another unit
@export
var follow_distance:float = 5.0

## Minimum time between switching between moving and not moving
## when following another unit
@export
var follow_movement_change_interval:float = 2.0

## Minimum distance from a unit container component asset (e.g. Bunker) before a unit will load into it
@export
var load_into_distance:float = 3.0
		
func _ready() -> void:
	if not unit:
		push_error("%s: Unit is not set" % name)
		return
	
	behavior_tree.actor_node_path = unit.get_path()
	behavior_tree.actor = unit
	
	_unit_nav = GameUnitNavigation.get_component(unit, false)
	if _unit_nav:
		_initial_stuck_detection = _unit_nav.enable_stuck_detection
	
	if unit.weapon:
		unit.weapon.weapon_controller.shoot_intent_toggled.connect(_on_shoot_intent_toggled)
	
	SignalBus.on_unit_command_finished.connect(_on_command_finished.unbind(1))
	_update_tree_state.call_deferred()
		
func _on_command_finished(in_unit: Unit, command:StringName, command_id:int) -> void:
	if in_unit != unit:
		return
		
	_command_counter -= 1
	
	# If command counter naturally goes to zero or if all actions canceled then switch to idle state and reset counter
	if _command_counter <= 0 or not blackboard.current_action:
		# Optimization to not tick the tree if there is nothing to do
		enabled = false
		_command_counter = 0
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command finished" % [name, StringUtils.safe_name(in_unit), command])
	command_finished.emit(command_id)

func _update_tree_state() -> void:
	behavior_tree.enabled = enabled
	
	idle_state.my_unit = unit
	idle_state.enabled = not enabled and unit.is_visible_in_tree()

func move(target_position:Vector3) -> void:
	_new_action()
	_clear_hold()
	
	blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Move)
	blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)
	
	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Move, _command_id, _set_command_args({
		&"position" : target_position
	} as Dictionary[StringName, Variant]))
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command ordered -> %s" % [name, StringUtils.safe_name(unit), UnitBlackboard.Action.Move, target_position])
	
func attack(enemy:Node3D) -> void:
	_clear_hold()
	_do_attack(enemy)
	
func _do_attack(enemy:Node3D) -> void:
	assert(enemy and enemy.is_in_group(Groups.TeamAsset), "%s: %s attaack %s - not a TeamAsset!" % [name, unit.name, StringUtils.safe_name(enemy)])
	_new_action()
	
	blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Attack)
	blackboard.set_value(UnitBlackboard.Keys.TargetNode, enemy)

	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Attack, _command_id, _set_command_args({
		&"target_id" : enemy.get_instance_id()
	} as Dictionary[StringName, Variant]))
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command ordered -> %s" % [name, StringUtils.safe_name(unit), UnitBlackboard.Action.Attack, StringUtils.safe_name(enemy)])

# Stuck detection needs to be turned off during attacks as units often stationary
func _on_shoot_intent_toggled(shooting:bool) -> void:
	_toggle_stuck_detection(not shooting)
	
func _toggle_stuck_detection(enable:bool) -> void:
	if not _unit_nav:
		return
	_unit_nav.enable_stuck_detection = _initial_stuck_detection if enable else false
	
func attack_position(target_position:Vector3) -> void:
	_new_action()
	_clear_hold()
	
	blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Attack)
	blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)

	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Attack, _command_id, _set_command_args({
		&"target_position": target_position
	} as Dictionary[StringName, Variant]))
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command ordered -> %s" % [name, StringUtils.safe_name(unit), UnitBlackboard.Action.Attack, target_position])
	
func move_and_attack(target_position:Vector3) -> void:
	_new_action()
	_clear_hold()
	
	blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.MoveAndAttack)
	blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)

	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.MoveAndAttack, _command_id, _set_command_args({
		&"position": target_position
	} as Dictionary[StringName, Variant]))
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command ordered -> %s" % \
			[name, StringUtils.safe_name(unit), UnitBlackboard.Action.MoveAndAttack, target_position])

func _set_command_args(args:Dictionary[StringName, Variant]) -> Dictionary[StringName, Variant]:
	blackboard.set_value(UnitBlackboard.Keys.CommandArgs, args)
	return args
	
	
## Follows the indicated friendly unit with an option to either continue following indefinitely (true)
## or only until the leader's current action completes (false)
## Following will always be canceled if a new command issued to this unit or the friendly unit dies
func follow(friendly:Unit, until_canceled:bool = true) -> void:
	_new_action()
	_clear_hold()
	
	_move_tracker = MoveTracker.new()
	_move_tracker.leader = friendly
	_move_tracker.follower = unit
	_move_tracker.follow_forever = until_canceled
	
	add_child(_move_tracker)
	
	blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Follow)
	blackboard.set_value(UnitBlackboard.Keys.TargetNode, friendly)
	blackboard.set_value(UnitBlackboard.Keys.FollowDistance, follow_distance)
	blackboard.set_value(UnitBlackboard.Keys.FollowMovementChangeInterval, follow_movement_change_interval)
	
	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Follow, _command_id, _set_command_args({
		&"target_id": friendly.get_instance_id()
	} as Dictionary[StringName, Variant]))
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command ordered -> %s" % [name, StringUtils.safe_name(unit), UnitBlackboard.Action.Follow, StringUtils.safe_name(friendly)])

func load_into(asset:Node3D) -> void:
	_new_action()
	_clear_hold()
	
	blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Load)
	blackboard.set_value(UnitBlackboard.Keys.TargetNode, asset)
	blackboard.set_value(UnitBlackboard.Keys.TargetPosition, asset.global_position)
	blackboard.set_value(UnitBlackboard.Keys.LoadIntoDistance, load_into_distance)
	
	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Load, _command_id, _set_command_args({
		&"target_id": asset.get_instance_id()
	} as Dictionary[StringName, Variant]))
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command ordered -> %s" % [name, StringUtils.safe_name(unit), UnitBlackboard.Action.Load, StringUtils.safe_name(asset)])

func stop() -> void:
	_clear_all_actions()
	_clear_hold()

	if LogUtils.debug:
		print_debug("%s(%s): Stop command ordered" % [name, StringUtils.safe_name(unit)])

func hold() -> void:
	# Ignore hold if in container
	if UnitContainerComponent.is_in_container(unit):
		print_debug("%s(%s): Hold command ignored as in a container" % [name, StringUtils.safe_name(unit)])
		return
	
	_clear_all_actions()
	blackboard.is_hold = true
	
	if LogUtils.debug:
		print_debug("%s(%s): Hold command ordered" % [name, StringUtils.safe_name(unit)])
	
func _new_action() -> void:
	unload_if_in_container()
	
	_command_counter += 1
	_command_id += 1
	_clear_all_actions()
	
	blackboard.action_id = _command_id
	
	# Call at end of frame so that caller of action has a change to read the command id before the command is issued
	command_issued.emit.call_deferred(_command_id)
	
func unload_if_in_container() -> bool:
	# If unit is in a container need to unload first before issuing new command	
	var container := UnitContainerComponent.get_container_for_unit(unit)
	if not container:
		return false
	return container.remove_unit(unit)
		
func _clear_all_actions() -> void:	
	blackboard.set_value(UnitBlackboard.Keys.Action, "")
	blackboard.erase_value(UnitBlackboard.Keys.TargetPosition)
	blackboard.erase_value(UnitBlackboard.Keys.TargetNode)
	blackboard.erase_value(UnitBlackboard.Keys.CommandArgs)
	
	if _move_tracker:
		_move_tracker.queue_free()
		_move_tracker = null
	
func is_attacking() -> bool:
	return blackboard.is_attacking
	
func get_attack_target() -> Unit:
	return blackboard.target_node if is_attacking() else null
	
func get_target_position() -> Vector3:
	return blackboard.target_position if has_target_position() else Vector3.INF

func has_target_position() -> bool:
	return blackboard.has_target_position
	
func is_moving() -> bool:
	return unit and unit.is_moving

func is_idle() -> bool:
	return _command_counter <= 0
	
func is_hold() -> bool:
	return blackboard.is_hold

func _on_idle_state_threat_selected(threat: Node3D) -> void:
	# Don't clear hold
	# TODO: Units without weapons should probably flee
	if unit.weapon:
		_do_attack(threat)
	
func _clear_hold() -> void:
	blackboard.erase_value(UnitBlackboard.Keys.HoldIssued)
