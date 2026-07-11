@tool
extends ActionLeaf

@onready var container_sweeper: UnitSweeper = %BunkerSweeper

func tick(actor: Node, _blackboard: Blackboard) -> int:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
	
	var load_target:Node3D = _get_available_load_target_if_applicable(unit, blackboard)
	
	if load_target:
		blackboard.set_load_into_target(load_target)
	else:
		blackboard.execute_position_callback()
	
	return SUCCESS

func _get_available_load_target_if_applicable(unit:Unit, blackboard:UnitDirectiveBlackboard) -> Node3D:
	var bounds := blackboard.bounds
	if not bounds:
		return null
	
	container_sweeper.vision_radius = bounds.radius
	
	var position:Vector3 = bounds.center
	var best_target:Node3D = null
	var min_dist_sq:float = INF
	
	var candidates: Array[Node3D] = container_sweeper.sweep_assets(position, [], unit.team)
	for candidate in candidates:
		var container := UnitContainerComponent.get_component(candidate, false)
		if not container or container.is_full:
			continue
		var dist_sq:float = candidate.global_position.distance_squared_to(position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_target = candidate
			
	return best_target
