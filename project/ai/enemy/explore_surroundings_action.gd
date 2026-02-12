@tool
extends ActionLeaf

@export
var move_radius:Vector2 = Vector2(100, 500)

@export
var heading_variation_degrees:Vector2 = Vector2(30,120)

@export
var world_boundaries_checker:WorldBoundariesChecker

const MAX_ATTEMPTS:int = 8
	
func _ready() -> void:
	if not world_boundaries_checker:
		push_warning("%s: WorldBoundariesChecker not set - no bounds testing on move targets!" % name)
		
func tick(_actor: Node, _blackboard: Blackboard) -> int:	
	var blackboard:EnemyTeamBlackboard = _blackboard
	
	for unit in blackboard.idle_units:
		_select_move_target(unit)
					
	return SUCCESS
	
func _select_move_target(unit:Unit) -> void:
	print_debug("%s: Select move target for unit=%s" % [name, unit.name])
	
	var target_pos:Vector3 = _get_move_target(unit)
	unit.get_or_add_actions().move(target_pos)

func _get_move_target(unit:Unit) -> Vector3:
	var pos:Vector3 = unit.global_position
	var heading:Vector3 = unit.global_forward
	
	var heading_deviation_deg:float = randf_range(heading_variation_degrees.x, heading_variation_degrees.y)
	var new_heading:Vector3 = heading.rotated(Vector3.UP, deg_to_rad(heading_deviation_deg))
	
	var result:PackedVector3Array
	result.resize(1)
	
	# If fail, try different orientations and reduce distance variance
	for i in MAX_ATTEMPTS:
		var max_distance:float = maxf(move_radius.x, move_radius.y * (1.0 - 0.2 * i))
		if i > 0:
			new_heading = new_heading.rotated(Vector3.UP, PI / i * (1.0 if i % 2 == 0 else -1.0))
		if _try_potential_target(pos, new_heading, max_distance, result):
			return result[0]
	push_warning("%s: %s - Could not find viable position after %d attempts from %s" % \
		[name, unit.name, MAX_ATTEMPTS, pos])		
	return pos
		
func _try_potential_target(pos:Vector3, heading:Vector3, max_distance:float, out_result:PackedVector3Array) -> bool:
	var distance:float = randf_range(move_radius.x, max_distance)
	var target_pos:Vector3 = pos + heading * distance
	
	if not world_boundaries_checker or world_boundaries_checker.is_within_bounds(target_pos):
		out_result[0] = target_pos
		return true
	return false		
