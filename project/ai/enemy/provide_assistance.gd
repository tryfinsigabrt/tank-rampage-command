@tool
extends ActionLeaf

var _candidate_units:Dictionary[int,AssistanceScore]

class AssistanceScore:
	var unit:Unit
	var score:float
	var strength:float
	
	func _init(in_unit:Unit) -> void:
		unit = in_unit
		strength = in_unit.attributes.strength
	
func tick(_actor: Node, in_blackboard: Blackboard) -> int:
	var blackboard: EnemyTeamBlackboard = in_blackboard
	
	var assistance_requests := blackboard.assistance_requests
	
	if not assistance_requests:
		return SUCCESS
	
	var available_units := blackboard.idle_units
	if not available_units:
		return SUCCESS
	
	assistance_requests.sort_custom(func(a:EnemyTeamBlackboard.AssistanceRequest, b:EnemyTeamBlackboard.AssistanceRequest) -> bool:
		return a.priority > b.priority	
	)
	
	_candidate_units.clear()
	for unit in available_units:
		if not is_instance_valid(unit):
			continue
		var attributes:TeamAssetAttributes = unit.attributes
		if attributes and attributes.strength > 0:
			_candidate_units[unit.get_instance_id()] = AssistanceScore.new(unit)
	
	# Score based on proximity and strength match
	for request in assistance_requests:		
		var total_strength:float = request.strength
		var target:Vector3 = request.location
		
		# First calculate distance score so we can normalize
		var max_dist:float = 0.0
		for unit_id in _candidate_units:
			var unit_score:AssistanceScore = _candidate_units[unit_id]
			var unit:Unit = unit_score.unit
			var dist_sq := unit.global_position.distance_squared_to(target)
			max_dist = maxf(dist_sq, max_dist)
			unit_score.score = dist_sq
			
		for unit_id in _candidate_units:
			var unit_score:AssistanceScore = _candidate_units[unit_id]
			var strength:float = unit_score.strength
			
			# First normalize existing distance score and apply weight
			var score:float = (1.0 - unit_score.score / max_dist) * 1.5
			
			var strength_score:float = strength / total_strength
			# Penalty for going over
			if strength_score > 1:
				strength_score -= 0.5
				
			score += strength_score
			unit_score.score = score
			
		var scores: Array[AssistanceScore] = _candidate_units.values()
		scores.sort_custom(func(a:AssistanceScore, b:AssistanceScore) -> bool:
			return a.score > b.score
		)
		# Greedily pick top scores until strength criteria met
		for score in scores:
			var strength:float = score.strength
			request.strength -= strength
			var unit:Unit = score.unit
			_candidate_units.erase(unit.get_instance_id())
			
			var directive:AiUnitDirectives = AiUnitDirectives.get_component(unit)
			directive.set_defend_position(target, request.min_duration)
			if request.strength <= 0:
				break
				
		if _candidate_units.is_empty():
			break
	# If strength met then remove
	for i in range(assistance_requests.size() - 1, -1, -1):
		var request := assistance_requests[i]
		if request.strength <= 0:
			assistance_requests.remove_at(i)
			
	_candidate_units.clear()
	return SUCCESS
