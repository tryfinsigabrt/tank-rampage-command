@tool
extends UnitCommandDecorator

var _leader:Node3D

func before_run(actor: Node, in_blackboard: Blackboard) -> void:
	super(actor, in_blackboard)
	var blackboard:UnitBlackboard = in_blackboard
	_leader = blackboard.target_node
	
func _should_continue_running(in_blackboard: Blackboard) -> bool:
	var blackboard:UnitBlackboard = in_blackboard

	var leader:Node3D = blackboard.target_node	
	return is_instance_valid(leader) and leader == _leader
