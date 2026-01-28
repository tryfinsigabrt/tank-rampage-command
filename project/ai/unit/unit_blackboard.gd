class_name UnitBlackboard extends Blackboard

class Action:
	const Move:StringName = &"move"
	const AttackUnit:StringName = &"attack_unit"
	const Follow:StringName = &"follow"
	const MoveAndAttack:StringName = &"move_and_attack"


class Keys:
	const TargetPosition:StringName = &"target_position"
	const Action:StringName = &"action"
	const TargetUnit:StringName = &"target_unit"
