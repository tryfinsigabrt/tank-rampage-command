@tool
extends ActionLeaf

@onready var load_target_finder: AvailableLoadTargetFinder = %LoadTargetFinder

@export
var max_angle_degrees:float = 15.0
	
func tick(actor: Node, _blackboard: Blackboard) -> int:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
	var position:Vector3 = blackboard.position
	var load_target:Node3D = load_target_finder.find_best_load_target_along_path(unit, position)
	
	if load_target:
		blackboard.set_load_into_target(load_target)
		return SUCCESS
	return FAILURE
