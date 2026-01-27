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
	
	_update_tree_state()
		
func _update_tree_state() -> void:
	behavior_tree.enabled = enabled

# TODO: This will update the appropriate behavior tree state		
func move(target_position:Vector3) -> void:
	pass

func attack(enemy:Unit) -> void:
	pass

func move_and_attack(target_position:Vector3) -> void:
	pass

func follow(friendly:Unit) -> void:
	pass
