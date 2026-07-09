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
	var control_point_data:ControlPointData
	var bounds: BoundingCircle
	var threat_strength:float
	var assist_context: Array[AssistContext]
	var positive_units:int
	
enum ControlPointState
{
	NEUTRAL,
	OURS,
	THEIRS
}
	
class ControlPointData:
	var control_point:ControlPoint
	var state:ControlPointState
	var last_update:float
	var team:int
	var visible:bool
	
	func _init(in_team:int, in_control_point:ControlPoint) -> void:
		control_point = in_control_point
		team = in_team
		update_state()
	
	func update_state() -> void:
		if control_point.neutral:
			state = ControlPointState.NEUTRAL
		elif control_point.team_component.is_ally_team(team):
			state = ControlPointState.OURS
		else:
			state = ControlPointState.THEIRS
		
		last_update = GameManager.game_timer.time_seconds
	
var _control_point_info:Dictionary[int, ControlPointData]
#var _assigned_units_by_control_point: Dictionary[int, PackedInt64Array]

func _on_control_point_visibility_changed(control_point: ControlPoint, in_is_visible: bool) -> void:		
	var id:int = control_point.get_instance_id()
	var existing:bool = id in _control_point_info
	if in_is_visible and not existing:
		_control_point_info[id] = ControlPointData.new(blackboard.team, control_point)
	elif existing:
		var cpd: ControlPointData = _control_point_info[id]
		cpd.visible = in_is_visible
		
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
	
	for id in _control_point_info:
		var control_point_data: ControlPointData = _control_point_info[id]
		if control_point_data.visible:
			control_point_data.update_state()

		var control_point := control_point_data.control_point
		
		var context := score_control_point(control_point_data, threats)
		cp_contexts.push_back(context)
		
		# If control point isn't enemy controlled, add a defense need
		if control_point.neutral or control_point.owned_team == blackboard.team:
			blackboard.defense_need_updated.emit(EnemyTeamBlackboard.DefenseNeedType.CONTROL_POINT, context)
			
		var assist_context := context.assist_context
		var score := context.score
		if score > 0:
			assist_context.sort_custom(func(a:AssistContext, b:AssistContext) -> bool:
				return a.score > b.score
			)
			score_sum += score
			prioritized_cps.push_back(context)
		
		print("%s: CONTROL POINT %s SCORE=%.1f: Top_unit=%.1f" % [name, control_point.name, score, \
			assist_context.front().score if not assist_context.is_empty() else 0.0])
	
	prioritized_cps.sort_custom(func(a:ControlPointContext, b:ControlPointContext) -> bool:
		return a.score > b.score
	)
	
	# Initial simple strategy - take up to max units mitigated by how many available units and ones we want to capture
	for control_point_ctx in prioritized_cps:
		var score_weight:float = control_point_ctx.score / score_sum
		var max_units:int = min(max_units_per_control_point, control_point_ctx.positive_units, floori(
			available_units.size() * score_weight))
		if max_units == 0:
			continue
			
		var control_point := control_point_ctx.control_point_data.control_point
		
		var count:int = 0
		for context in control_point_ctx.assist_context:
			var unit := context.unit
			var unit_id:int = unit.get_instance_id()
			if not unit_id in available_units:
				continue
						
			var unit_directives := AiUnitDirectives.get_component(unit)
			# TODO: hard coding a high priority of 20
			# Hold for an additional capture time * 2 after captured without being contested
			unit_directives.set_defend_control_point(control_point, control_point.capture_time * 2.0, 20, "CONTROL_POINT")
			
			count += 1
			available_units.erase(unit_id)
			if count == max_units:
				break
		print("%s: CONTROL POINT %s: %d units dispatched" % [name, control_point.name, count])	
	
func score_control_point(control_point_data: ControlPointData, threats: Array[EnemyThreatContext]) -> ControlPointContext:
	var score:float = 0.0
	var our_team:int = blackboard.team
	var control_point: ControlPoint = control_point_data.control_point
	var known_state := control_point_data.state
	
	var control_bounds: Bounds = Bounds.new(control_point.get_global_bounds(), Bounds.Type.SPHERE_INSCRIBED)
	var control_bounds_influence: BoundingCircle = BoundingCircle.from_sphere(control_bounds.inscribed_sphere)
	control_bounds_influence.radius = control_point_influence_radius
	
	var threat_strength:float = 0.0
	# Score threats relative to the control point bounds before considering assisting units
	
	for threat in threats:
		var threat_bounds: BoundingCircle = threat.bounds
		if control_bounds_influence.overlaps(threat_bounds):
			threat_strength += threat.strength
	
	score -= sqrt(threat_strength)
	
	# TODO: Need to add in any defensive structures within the influence bounds	
	var control_point_friendlies: Array[Unit] = control_point.get_units_by_team(our_team)
	var team_units: Array[Unit] = blackboard.team_info.units
	
	var cp_position:Vector3 = control_point.global_position
	var cp_grid_pos:Vector2 = MathUtils.grid_vector(cp_position)
	
	var assist_contexts: Array[AssistContext]
	
	var positive_units:int = 0
	var our_strength:float = 0
	
	for unit in team_units:
		# Only assist if have a weapon - i.e. not a transport type unit
		if not unit.weapon:
			continue
			
		var assist_context := AssistContext.new(unit)
		var strength:float = assist_context.strength
		
		var pos:Vector3 = unit.global_position
		var unit_weapon:Weapon = unit.weapon
		var ranged_weapon:bool = not unit_weapon.prefer_close_shots
		var weapon_range:Vector2 = unit_weapon.ideal_fire_range
			
		var grid_pos:Vector2 = MathUtils.grid_vector(pos)
		var to_cp2_dir:Vector2 = grid_pos.direction_to(cp_grid_pos)
		
		var unit_score:float = 0.0
		
		var in_control_point:bool = false
		if unit in control_point_friendlies:
			unit_score = 15.0
			in_control_point = true
			our_strength += strength
		elif control_bounds_influence.contains(grid_pos) or \
		 (ranged_weapon and MathUtils.is_between(control_bounds.distance_to(pos), weapon_range)):
			unit_score = 5.0
			our_strength += strength
		else:
			# score and strength diminishes by distance outside
			var dist:float = control_bounds_influence.distance_to(grid_pos)
			var log_dist:float = maxf(log(dist), 0.0)
			
			unit_score = 5.0 - log_dist
			our_strength += strength / maxf(log_dist, 1.0)
		
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
	
	# END For every team unit
	
	if control_point.owned_team == our_team:
		score += 5.0
		if control_point.is_being_captured():
			score += 50.0
		elif control_point.is_constested():
			score += 15.0
		else:
			# If we are overmatched and no threats then reduce score
			if our_strength > threat_strength:
				score -= our_strength - threat_strength
	elif control_point.capturing_team == our_team:
		score += 3.0
		if control_point.is_being_captured():
			score += 50.0
		elif control_point.is_constested():
			score += 20.0
	elif known_state == ControlPointState.NEUTRAL:
		score += 100.0
	# Penalty if known to be enemy occupied and we are not currently capturing as need a stronger attacking force
	elif known_state == ControlPointState.THEIRS:
		score -= 6.0
		
	var cp_context := ControlPointContext.new()
	cp_context.assist_context = assist_contexts
	cp_context.control_point_data = control_point_data
	cp_context.score = score
	cp_context.threat_strength = threat_strength
	cp_context.positive_units = positive_units
	cp_context.bounds = BoundingCircle.from_sphere(control_bounds.inscribed_sphere)
	
	return cp_context
