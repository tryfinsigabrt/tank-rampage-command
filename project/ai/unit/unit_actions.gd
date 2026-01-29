class_name UnitActions extends Node3D

@onready var behavior_tree: BeehaveTree = $BeehaveTree

@export
var unit:Unit

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
		
func _on_command_finished(in_unit: Unit) -> void:
	if in_unit != unit:
		return
	# Optimization to not tick the tree if there is nothing to do
	enabled = false
	
func _update_tree_state() -> void:
	behavior_tree.enabled = enabled

func move(target_position:Vector3) -> void:
	_clear_all_actions()
	
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Move)
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)
	
	enabled = true
	
func attack(enemy:Unit) -> void:
	_clear_all_actions()
	
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.AttackUnit)
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.TargetUnit, enemy)

	enabled = true
	
func move_and_attack(target_position:Vector3) -> void:
	_clear_all_actions()
	
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.MoveAndAttack)
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)

	enabled = true
	
func follow(_friendly:Unit) -> void:
	push_error("Not implemented")

func _clear_all_actions() -> void:
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, "")
