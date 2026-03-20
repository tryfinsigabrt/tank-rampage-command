class_name UnitBlackboard extends Blackboard

class Action:
	const Move:StringName = &"move"
	const Attack:StringName = &"attack"
	const Follow:StringName = &"follow"
	const MoveAndAttack:StringName = &"move_and_attack"


class Keys:
	const TargetPosition:StringName = &"target_position"
	const Action:StringName = &"action"
	const TargetUnit:StringName = &"target_unit"


var current_action:StringName:
	get:
		return get_value(Keys.Action,&"")
	set(value):
		set_value(Keys,Action, value)

var target_position:Vector3:
	get:
		return get_value(Keys.TargetPosition, Vector3.ZERO)
	set(value):
		set_value(Keys.TargetPosition, value)

var target_unit:Unit:
	get:
		return get_value(Keys.TargetUnit)
	set(value):
		set_value(Keys.TargetUnit, value)
		
var is_attacking:bool:
	get:
		return current_action == Action.Attack
		
