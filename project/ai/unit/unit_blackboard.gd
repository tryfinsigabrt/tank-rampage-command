class_name UnitBlackboard extends Blackboard

class Action:
	const Move:StringName = &"move"
	const Attack:StringName = &"attack"
	const Follow:StringName = &"follow"
	const MoveAndAttack:StringName = &"move_and_attack"
	const Stop:StringName = &"stop"
	const Hold:StringName = &"hold"

class Keys:
	const TargetPosition:StringName = &"target_position"
	const Action:StringName = &"action"
	const ActionId:StringName = &"action_id"
	const TargetNode:StringName = &"target_node"
	const HoldIssued:StringName = &"hold"

var current_action:StringName:
	get:
		return get_value(Keys.Action,&"")
	set(value):
		set_value(Keys,Action, value)

var action_id:int:
	get:
		return get_value(Keys.ActionId, 0)
	set(value):
		set_value(Keys.ActionId, value)
		
var has_target_position:bool:
	get:
		return has_value(Keys.TargetPosition)
		
var target_position:Vector3:
	get:
		return get_value(Keys.TargetPosition, Vector3.INF)
	set(value):
		set_value(Keys.TargetPosition, value)

var target_node:Node3D:
	get:
		return get_value(Keys.TargetNode)
	set(value):
		set_value(Keys.TargetNode, value)
		
var is_attacking:bool:
	get:
		return current_action == Action.Attack
		
var is_hold:bool:
	get:
		return get_value(Keys.HoldIssued, false)
	set(value):
		set_value(Keys.HoldIssued, value)
