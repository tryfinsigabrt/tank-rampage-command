class_name UnitActions extends Node3D

signal command_issued(command_id:int)
signal command_finished(command_id:int)

@onready var behavior_tree: BeehaveTree = $BeehaveTree
@onready var blackboard: UnitBlackboard = $Blackboard
@onready var idle_state: IdleUnitState = $IdleState

@export
var unit:Unit

var _unit_nav:GameUnitNavigation
var _initial_stuck_detection:bool

var _command_counter:int

var _command_id:int

var last_command_id:int:
	get:
		return _command_id

@export
var enabled:bool:
	set(value):
		enabled = value
		_update_tree_state()
	get:
		return enabled
			
func _ready() -> void:
	if not unit:
		push_error("%s: Unit is not set" % name)
		return
		
	behavior_tree.actor_node_path = unit.get_path()
	behavior_tree.actor = unit
	
	_unit_nav = Groups.get_child_with_type(unit, GameUnitNavigation)
	if _unit_nav:
		_initial_stuck_detection = _unit_nav.enable_stuck_detection
	
	unit.shoot_intent_toggled.connect(_on_shoot_intent_toggled)
	
	SignalBus.on_unit_command_finished.connect(_on_command_finished.unbind(1))
	_update_tree_state.call_deferred()
		
func _on_command_finished(in_unit: Unit, command:StringName, command_id:int) -> void:
	if in_unit != unit:
		return
		
	_command_counter -= 1
	
	if _command_counter <= 0:
		# Optimization to not tick the tree if there is nothing to do
		enabled = false
		_command_counter = 0
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command finished" % [name, StringUtils.safe_name(in_unit), command])
	command_finished.emit(command_id)

func _update_tree_state() -> void:
	behavior_tree.enabled = enabled
	
	idle_state.my_unit = unit
	idle_state.enabled = not enabled

func move(target_position:Vector3) -> void:
	_new_action()
	_clear_hold()
	
	blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Move)
	blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)
	
	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Move, _command_id, {
		&"position" : target_position
	} as Dictionary[StringName, Variant])
	
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
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Attack, _command_id, {
		&"target_node": enemy
	} as Dictionary[StringName, Variant])
	
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
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Attack, _command_id, {
		&"target_position": target_position
	} as Dictionary[StringName, Variant])
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command ordered -> %s" % [name, StringUtils.safe_name(unit), UnitBlackboard.Action.Attack, target_position])
	
func move_and_attack(target_position:Vector3) -> void:
	_new_action()
	_clear_hold()
	
	blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.MoveAndAttack)
	blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)

	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.MoveAndAttack, _command_id, {
		&"position": target_position
	} as Dictionary[StringName, Variant])
	
	if LogUtils.debug:
		print_debug("%s(%s): %s command ordered -> %s" % \
			[name, StringUtils.safe_name(unit), UnitBlackboard.Action.MoveAndAttack, target_position])
	
func follow(_friendly:Unit) -> void:
	push_error("Not implemented")

func stop() -> void:
	_clear_all_actions()
	_clear_hold()

	if LogUtils.debug:
		print_debug("%s(%s): Stop command ordered" % [name, StringUtils.safe_name(unit)])

func hold() -> void:
	_clear_all_actions()
	blackboard.is_hold = true
	
	if LogUtils.debug:
		print_debug("%s(%s): Hold command ordered" % [name, StringUtils.safe_name(unit)])

func _new_action() -> void:
	_command_counter += 1
	_command_id += 1
	_clear_all_actions()
	
	blackboard.action_id = _command_id
	
	# Call at end of frame so that caller of action has a change to read the command id before the command is issued
	command_issued.emit.call_deferred(_command_id)
	
func _clear_all_actions() -> void:
	blackboard.set_value(UnitBlackboard.Keys.Action, "")
	blackboard.erase_value(UnitBlackboard.Keys.TargetPosition)
	blackboard.erase_value(UnitBlackboard.Keys.TargetNode)
	
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
	_do_attack(threat)
	
func _clear_hold() -> void:
	blackboard.erase_value(UnitBlackboard.Keys.HoldIssued)
