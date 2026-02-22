class_name UnitActions extends Node3D

@onready var behavior_tree: BeehaveTree = $BeehaveTree
@onready var blackboard: UnitBlackboard = $Blackboard
@onready var idle_state: IdleUnitState = $IdleState

@export
var unit:Unit

var _command_counter:int

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
	
	SignalBus.on_unit_command_finished.connect(_on_command_finished.unbind(1))
	_update_tree_state()
		
func _on_command_finished(in_unit: Unit, command:StringName) -> void:
	if in_unit != unit:
		return
		
	_command_counter -= 1
	
	if _command_counter <= 0:
		# Optimization to not tick the tree if there is nothing to do
		enabled = false
		_command_counter = 0
	
	print_debug("%s(%s): %s command finished" % [name, StringUtils.safe_name(in_unit), command])
	
func _update_tree_state() -> void:
	behavior_tree.enabled = enabled
	
	idle_state.my_unit = unit
	idle_state.enabled = not enabled

func move(target_position:Vector3) -> void:
	_new_action()
	
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Move)
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)
	
	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.Move, {
		&"position" : target_position
	} as Dictionary[StringName, Variant])
	
	print_debug("%s(%s): %s command ordered -> %s" % [name, StringUtils.safe_name(unit), UnitBlackboard.Action.Move, target_position])
	
func attack(enemy:Unit) -> void:
	_new_action()
	
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.AttackUnit)
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.TargetUnit, enemy)

	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.AttackUnit, {
		&"target": enemy
	} as Dictionary[StringName, Variant])
	
	print_debug("%s(%s): %s command ordered -> %s" % [name, StringUtils.safe_name(unit), UnitBlackboard.Action.AttackUnit, StringUtils.safe_name(unit)])
	
func move_and_attack(target_position:Vector3) -> void:
	_new_action()
	
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.MoveAndAttack)
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)

	enabled = true
	
	SignalBus.on_unit_command_scheduled.emit(unit, UnitBlackboard.Action.MoveAndAttack, {
		&"position": target_position
	} as Dictionary[StringName, Variant])
	
	print_debug("%s(%s): %s command ordered -> %s" % \
		[name, StringUtils.safe_name(unit), UnitBlackboard.Action.MoveAndAttack, target_position])
	
func follow(_friendly:Unit) -> void:
	push_error("Not implemented")

func _new_action() -> void:
	_command_counter += 1
	_clear_all_actions()
	
func _clear_all_actions() -> void:
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, "")
	
func is_attacking() -> bool:
	return blackboard.is_attacking
	
func get_attack_target() -> Unit:
	return blackboard.target_unit if is_attacking() else null
	
func is_moving() -> bool:
	return unit and unit.is_moving

func is_idle() -> bool:
	return _command_counter <= 0

func _on_idle_state_threat_selected(threat: Unit) -> void:
	attack(threat)
