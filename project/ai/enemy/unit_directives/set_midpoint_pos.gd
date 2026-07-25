@tool
@abstract
class_name SetMidpointPosition extends ActionLeaf

@export
var min_move_distance:float = 10.0

@export
var target_position_key:StringName

@export_range(0.0, 1.0, 0.01)
var our_unit_weight:float = 0.5

@abstract
func _get_other_units(directive:AiUnitDirectives) -> Array[Unit]
	
func tick(actor: Node, _blackboard: Blackboard) -> int:
	if not target_position_key:
		return FAILURE
		
	var directive:AiUnitDirectives = actor
	
	var other_units:Array[Unit] = _get_other_units(directive)
	if not other_units:
		return FAILURE
	
	var unit:Unit = directive.unit
			
	var avg_pos:Vector3 = Vector3.ZERO
	var unit_pos:Vector3 = unit.global_position

	# Select edge of bounds in dir
	for other_unit in other_units:
		# Use edge of bounds
		var pos:Vector3 = _get_target_position(other_unit, unit_pos)
		avg_pos += pos
	
	avg_pos /= other_units.size()
	
	var unit_target_pos:Vector3 = _get_target_position(unit, avg_pos)
	# Weighted midpoint between this average other units position and our position
	var target_position:Vector3 = avg_pos * (1.0 - our_unit_weight) + unit_target_pos * our_unit_weight
	
	if min_move_distance > 0:
		var dist_sq:float = unit_pos.distance_squared_to(target_position)
		if dist_sq < min_move_distance * min_move_distance:
			return FAILURE
	
	var blackboard:UnitDirectiveBlackboard = _blackboard
	blackboard.update_state_data(target_position_key, target_position)
	
	return SUCCESS

static func _get_target_position(unit:Unit, compare_pos:Vector3) -> Vector3:
	# Use edge of bounds
	var bounds:BoundingCircle = BoundingCircle.from_aabb(unit.get_global_bounds(), true)
	var current_pos:Vector3 = unit.global_position
	var pos_grid:Vector2 = bounds.closest_point_to(MathUtils.grid_vector(compare_pos))
	
	return Vector3(pos_grid.x, current_pos.y, pos_grid.y)
