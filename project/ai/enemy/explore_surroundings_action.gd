@tool
extends ActionLeaf

@export
var move_radius:Vector2 = Vector2(100, 500)

@export
var heading_variation_degrees:Vector2 = Vector2(30,120)
	
func tick(_actor: Node, _blackboard: Blackboard) -> int:	
	var blackboard:EnemyTeamBlackboard = _blackboard
	var units:Dictionary[int,Unit] = blackboard.team_info.units_dict
	
	# TODO: EnemyActionPrioritizer will explicitly add in an exploring units directive
	for unit_id in blackboard.idle_units:
		var unit:Unit = units.get(unit_id)
		if unit:
			_select_move_target(unit)
					
	return RUNNING
	
func _select_move_target(unit:Unit) -> void:
	print_debug("%s: Select move target for unit=%s" % [name, unit.name])
	
	var pos:Vector3 = unit.global_position
	var heading:Vector3 = unit.global_forward
	
	var distance:float = randf_range(move_radius.x, move_radius.y)
	var heading_deviation_deg:float = randf_range(heading_variation_degrees.x, heading_variation_degrees.y)
	
	var new_heading:Vector3 = heading.rotated(Vector3.UP, deg_to_rad(heading_deviation_deg))
	
	var target_pos:Vector3 = pos + new_heading * distance
	unit.get_or_add_actions().move(target_pos)
