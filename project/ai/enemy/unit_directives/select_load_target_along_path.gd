@tool
extends ActionLeaf

@export
var max_angle_degrees:float = 15.0
	
func tick(actor: Node, _blackboard: Blackboard) -> int:
	var directive:AiUnitDirectives = actor
	var unit:Unit = directive.unit
	var blackboard:UnitDirectiveBlackboard = _blackboard
	
	var load_target:Node3D = _get_available_load_target_if_applicable(unit)
	
	if load_target:
		blackboard.set_load_into_target(load_target)
		return SUCCESS
	return FAILURE

func _get_available_load_target_if_applicable(unit:Unit) -> Node3D:
	var match_team:MatchTeam = GameManager.find_match_team_by_id(unit.team)
	if not match_team:
		push_warning("%s: Could not determine match team for unit=%s" % [name, unit.name])
		return null
	
	var best_load_target:Node3D
	var best_dist_sq:float = INF
	
	var unit_pos := unit.global_position
	for asset:Node3D in match_team:
		if asset == unit:
			continue
			
		var unit_container:UnitContainerComponent = UnitContainerComponent.get_component(asset, false)
		if not unit_container or unit_container.is_full or not unit_container.supports_unit(unit):
			continue
		
		# Check heading and then see if best distance
		var container_pos := asset.global_position
		
		var angle_to_asset:float = unit_pos.angle_to(container_pos)
		if angle_to_asset > max_angle_degrees:
			continue
		
		var dist_sq:float = unit_pos.distance_squared_to(container_pos)
		if dist_sq < best_dist_sq:
			best_load_target = asset
			best_dist_sq = dist_sq
		
	return best_load_target
