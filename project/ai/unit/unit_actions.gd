class_name UnitActions extends Node3D

@onready var behavior_tree: BeehaveTree = $BeehaveTree

@export
var unit:Unit

# TODO: Intermediate refactoring step
const attack_action_scene = preload("res://player/attack_action.tscn")

@onready var _actions_container: Node3D = $ActionsContainer

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
	
	_update_tree_state()
		
func _update_tree_state() -> void:
	behavior_tree.enabled = enabled

func move(target_position:Vector3) -> void:
	_clear_all_actions()
	_issue_move_to(target_position)

func attack(enemy:Unit) -> void:
	_clear_all_actions()
	
	var attack_scene:AttackAction = attack_action_scene.instantiate()
	attack_scene.controlled_unit = unit
	
	attack_scene.targeted_unit = enemy
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(enemy.global_position, 10.0, Color.RED, 3.0)
	
	_actions_container.add_child(attack_scene)

func move_and_attack(target_position:Vector3) -> void:
	_clear_all_actions()
	
	var attack_scene:AttackAction = attack_action_scene.instantiate()
	attack_scene.controlled_unit = unit
	
	# TODO: Only attack threats while moving
	# Right now just attacking the location itself repeatedly
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(target_position, 5.0, Color.ORANGE, 3.0)
		
	attack_scene.targeted_location = target_position
	_actions_container.add_child(attack_scene)

func follow(_friendly:Unit) -> void:
	push_error("Not implemented")

#region Intermediate Logic

func _clear_all_actions() -> void:
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, "")

	for node in _actions_container.get_children():
		node.queue_free()

func _issue_move_to(target_position: Vector3) -> void:
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.Action, UnitBlackboard.Action.Move)
	behavior_tree.blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target_position)
	
#endregion
