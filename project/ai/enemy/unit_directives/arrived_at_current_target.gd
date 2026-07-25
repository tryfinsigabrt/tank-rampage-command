@tool
extends ActionLeaf

const CURRENT_BOUNDS_KEY:String = "ACT_BOUNDS"
	
func before_run(_actor: Node, _blackboard: Blackboard) -> void:
	var blackboard:UnitDirectiveBlackboard = _blackboard
	var bounds:BoundingSphere = blackboard.bounds
	var last_bounds:BoundingSphere = blackboard.get_value(CURRENT_BOUNDS_KEY) as BoundingSphere
	
	# bounds object must have changed to execute again
	if last_bounds != bounds:
		blackboard.update_state_data(CURRENT_BOUNDS_KEY, bounds)
	else:
		blackboard.erase_state_key(CURRENT_BOUNDS_KEY)

func after_run(actor: Node, _blackboard: Blackboard) -> void:
	var blackboard:UnitDirectiveBlackboard = _blackboard
	blackboard.erase_state_key(CURRENT_BOUNDS_KEY)
	super(actor, _blackboard)
		
func tick(actor: Node, blackboard: Blackboard) -> int:
	var current_bounds:BoundingSphere = blackboard.get_value(CURRENT_BOUNDS_KEY) as BoundingSphere
	if not current_bounds:
		return FAILURE
		
	# See if already in the bounds
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	
	var current_pos:Vector3 = unit.global_position
	
	if current_bounds.contains(current_pos):
		return SUCCESS
		
	return RUNNING
