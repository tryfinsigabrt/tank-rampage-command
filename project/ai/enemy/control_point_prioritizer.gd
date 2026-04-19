extends Node

@onready var rate_limiter: RateLimiter = $RateLimiter
@onready var tick: Timer = $Tick
@onready var blackboard: EnemyTeamBlackboard = %Blackboard

@export
var min_defend_score:float = 0.0

@export
var min_attack_score:float = 1.0

@export
var max_units_per_control_point:int = 10

@export
var control_point_influence_radius:float = 100.0

class AssistContext:
	var unit:Unit
	var strength:float
	var score:float
	
	func _init(in_unit:Unit) -> void:
		unit = in_unit
		strength = in_unit.strength()
	
class ControlPointContext:
	var score:float
	var control_point:ControlPoint
	var bounds: BoundingCircle
	var threat_strength:float
	var assist_context: Array[AssistContext]
	var positive_units:int
	
var _known_control_points: Array[ControlPoint]
var _assigned_units_by_control_point: Dictionary[int, PackedInt64Array]

func _on_blackboard_on_control_point_discovered(control_point: ControlPoint) -> void:
	_known_control_points.push_back(control_point)
	tick.start()
	await _evaluate_priorities()

func _evaluate_priorities() -> void:
	var process := await rate_limiter.limit()
	if not process:
		return
	print_debug("%s: Evaluate Priorities" % name)
	
	var threats: Array[EnemyThreatContext] = blackboard.threats
	
	var cp_contexts: Array[ControlPointContext]
	
	var available_units: Dictionary[int, Unit]
	var all_units := blackboard.team_info.units
	for unit in all_units:
		if is_instance_valid(unit):
			available_units[unit.get_instance_id()] = unit 
			
	var prioritized_cps: Array[ControlPointContext]
	
	var score_sum:float = 0.0
	
	for control_point in _known_control_points:
		var context := score_control_point(control_point, threats)
		cp_contexts.push_back(context)
		
		var assist_context := context.assist_context
		var score := context.score
		if score > 0:
			assist_context.sort_custom(func(a:AssistContext, b:AssistContext) -> bool:
				return a.score > b.score
			)
			score_sum += score
			prioritized_cps.push_back(context)
		
		print("%s: CONTROL POINT SCORE=%.1f: Top_unit=%.1f" % [name, score, \
			assist_context.front().score if not assist_context.is_empty() else 0.0])
	
	prioritized_cps.sort_custom(func(a:ControlPointContext, b:ControlPointContext) -> bool:
		return a.score > b.score
	)
	
	# Initial dumb strategy - take up to max units mitigated by how many available units and ones we want to capture
	for control_point in prioritized_cps:
		var score_weight:float = control_point.score / score_sum
		var max_units:int = min(max_units_per_control_point, control_point.positive_units, floori(
			available_units.size() * score_weight))
		if max_units == 0:
			continue
			
		var bounds := control_point.bounds
		var cp_pos := control_point.control_point.global_position
		
		var count:int = 0
		for context in control_point.assist_context:
			var unit := context.unit
			var unit_id:int = unit.get_instance_id()
			if not unit_id in available_units:
				continue
			
			var unit_pos:Vector3 = unit.global_position
			var unit_pos2: Vector2 = MathUtils.grid_vector(unit_pos)
			if bounds.contains(unit_pos2):
				unit.get_or_add_actions().hold()
			else:
				unit.get_or_add_actions().move_and_attack(cp_pos)
			
			count += 1
			available_units.erase(unit_id)
			if count == max_units:
				break
			
	
func score_control_point(control_point: ControlPoint, threats: Array[EnemyThreatContext]) -> ControlPointContext:
	var score:float = 0.0
	var our_team:int = blackboard.team
	
	# Owned or capturing bonuses
	if control_point.owned_team == our_team:
		score += 5.0
		if control_point.is_being_captured():
			score += 25.0
		elif control_point.is_constested():
			score += 10.0
	elif control_point.capturing_team == our_team:
		score += 3.0
		if control_point.is_being_captured():
			score += 25.0
		elif control_point.is_constested():
			score += 7.0
		
	var control_bounds: Bounds = Bounds.new(control_point.get_global_bounds(), Bounds.Type.SPHERE_CIRCUMSCRIBED)
	var control_bounds_influence: BoundingCircle = BoundingCircle.from_sphere(control_bounds.circumscribed_sphere)
	control_bounds_influence.radius = control_point_influence_radius
	
	var threat_strength:float = 0.0
	# Score threats relative to the control point bounds before considering assisting units
	
	for threat in threats:
		var threat_bounds: BoundingCircle = threat.bounds
		if control_bounds_influence.overlaps(threat_bounds):
			threat_strength += threat.strength
	
	score -= sqrt(threat_strength)
	
	var control_point_friendlies: Array[Unit] = control_point.get_units_by_team(our_team)
	var team_units: Array[Unit] = blackboard.team_info.units
	
	var cp_position:Vector3 = control_point.global_position
	var cp_grid_pos:Vector2 = MathUtils.grid_vector(cp_position)
	
	var assist_contexts: Array[AssistContext]
	
	var positive_units:int = 0
	for unit in team_units:
		var assist_context := AssistContext.new(unit)
		var strength:float = assist_context.strength
		
		var pos:Vector3 = unit.global_position
		var grid_pos:Vector2 = MathUtils.grid_vector(pos)
		var to_cp2_dir:Vector2 = grid_pos.direction_to(cp_grid_pos)
		
		var unit_score:float = 0.0
		
		var in_control_point:bool = false
		if unit in control_point_friendlies:
			unit_score = 15.0
			in_control_point = true
		elif control_bounds_influence.contains(grid_pos):
			unit_score = 5.0
		else:
			# score and strength diminishes by distance outside
			var dist:float = control_bounds_influence.distance_to(grid_pos)
			unit_score = 5.0 - log(dist)
		
		unit_score += sqrt(strength)
		
		for threat in threats:
			var threat_bounds: BoundingCircle = threat.bounds
			if threat_bounds.contains(grid_pos) or (not in_control_point and threat_bounds.ray_intersects(grid_pos, to_cp2_dir)):
				unit_score -= threat.strength / strength
				
		assist_context.score = unit_score
		assist_contexts.push_back(assist_context)
		
		if unit_score > 0:
			score += unit_score
			positive_units += 1
	
	var cp_context := ControlPointContext.new()
	cp_context.assist_context = assist_contexts
	cp_context.control_point = control_point
	cp_context.score = score
	cp_context.threat_strength = threat_strength
	cp_context.positive_units = positive_units
	cp_context.bounds = BoundingCircle.from_sphere(control_bounds.circumscribed_sphere)
	
	return cp_context
