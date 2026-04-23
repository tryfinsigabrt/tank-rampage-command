@tool
extends ActionLeaf

@export
var min_resource_score:float = 1.0

@export
var resource_cache_duration:float = 5.0

var _time:float
var _cache:Dictionary[int, Dictionary]
var _cache_dirty:bool
var _team:int

class ScrapCache:
	var score:float
	var time:float
	
class ScrapContext:
	var resource: ScrapToken
	var score:float

class ScoreResult:
	var score: float
	var resource: ScrapToken
	var unit: Unit
	
	func _init(in_score:float, in_resource:ScrapToken, in_unit:Unit) -> void:
		self.score = in_score
		self.resource = in_resource
		self.unit = in_unit
		
	static func create(in_unit: Unit, context: ScrapContext) -> ScoreResult:
		return ScoreResult.new(context.score, context.resource, in_unit)
	
func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	SignalBus.on_unit_killed.connect(_on_unit_killed.unbind(1))
	SignalBus.on_scrap_collected.connect(_on_scrap_collected.unbind(2))
	
func _on_unit_killed(unit:Unit) -> void:
	if unit.is_on_team(_team):
		_cache_dirty = true
		
func _on_scrap_collected() -> void:
	_cache_dirty = true
	
func tick(_actor: Node, _blackboard: Blackboard) -> int:
	var blackboard:EnemyTeamBlackboard = _blackboard
	
	_team = blackboard.team
	
	var idle_units: Array[Unit] = blackboard.idle_units
	if not idle_units:
		return SUCCESS
		
	var resources: Array[ScrapContext] = _get_resources(blackboard)
	if not resources:
		return SUCCESS
		
	_time = GameManager.game_timer.time_seconds
	_cache = blackboard.resource_calculation_cache
	
	if _cache_dirty:
		_clean_cache()
	
	var threat_contexts := blackboard.threats
	
	var score_results: Array[ScoreResult]
	# Preallocate maximum required storage
	score_results.resize(idle_units.size() * resources.size())
	var count:int = 0
		
	for unit in idle_units:
		if not is_instance_valid(unit):
			continue
			
		for context in resources:
			_update_scrap_context(unit, context, threat_contexts)
		
		# Collect results and score all together to avoid a "unit greedy" algorithm
		# that will find a local maximum
		for context in resources:
			# Only add if above the threshold
			if context.score >= min_resource_score:
				score_results[count] = ScoreResult.create(unit, context)
				count += 1
		
	score_results.resize(count)
	score_results.sort_custom(func(a:ScoreResult, b:ScoreResult) -> bool:
		return a.score > b.score
	)
		
	var used_ids:Dictionary[int,bool]
	var selected_count:int = 0
	var max_resources:int = resources.size()
	var max_units:int = idle_units.size()
	# TODO: Send multiple units to a resource if it requires an "escort" due to the threat

	#print("%s: SELECTED RESOURCE SCORE - START *****************************************" % name)
	for best_resource_pairing in score_results:
		# Make sure we haven't already used the unit or the resource
		var unit:Unit = best_resource_pairing.unit
		var unit_id:int = unit.get_instance_id()
		
		var resource:ScrapToken = best_resource_pairing.resource
		var resource_id:int = resource.get_instance_id()
		
		if unit_id not in used_ids and resource_id not in used_ids:
			#print("%s: SELECTED RESOURCE SCORE - %s -> %s=%.1f" % [name, unit.name, resource.name, best_resource_pairing.score])
			used_ids[unit_id] = true
			used_ids[resource_id] = true
			selected_count += 1
			
			unit.get_or_add_actions().move_and_attack(resource.global_position)
			_track_unit_resource_connection(blackboard, unit, resource)
			
			#Exhausted assignments
			if selected_count == max_resources or selected_count == max_units:
				break
	#print("%s: SELECTED RESOURCE SCORE - END *****************************************" % name)
	
	return SUCCESS

func _track_unit_resource_connection(blackboard:EnemyTeamBlackboard, unit:Unit, resource:ScrapToken) -> void:
	# When command finished then free active resource assignment
	# This prevents the next tick assigning a different unit to the new resource because it forgot it was already assigned
	var holders: Array[Callable]
	holders.resize(2)
	
	var unit_id:int = unit.get_instance_id()
	var unit_actions := unit.get_or_add_actions()
	var command_id:int = unit_actions.last_command_id
	var resource_id:int = resource.get_instance_id()
	
	blackboard.assigned_resources.push_back(resource_id)
	
	holders[0] = func(id: int) -> void:
		if id == command_id:
			blackboard.assigned_resources.erase(resource_id)
			
			var cb := holders[0]
			if unit_actions.command_finished.is_connected(cb):
				unit_actions.command_finished.disconnect(cb)
			var active_unit:Unit = instance_from_id(unit_id) as Unit
			if active_unit:
				active_unit.died.disconnect(holders[1])
	
	# Unit died before the resource could be collected
	holders[1] = func() -> void:
		blackboard.assigned_resources.erase(resource_id)
		var other_cb := holders[0]
		if unit_actions.command_finished.is_connected(other_cb):
			unit_actions.command_finished.disconnect(other_cb)
			
	# Assigned resources also removed in the main enemy action prioritizer tree_exited signal for the resource
	unit_actions.command_finished.connect(holders[0])
	unit.died.connect(holders[1].unbind(1), CONNECT_ONE_SHOT)
			
func _clean_cache() -> void:
	for unit_id:int in _cache.keys():
		if is_instance_id_valid(unit_id):
			var resource_scores:Dictionary[int, ScrapCache] = _cache[unit_id]
			for resource_id:int in _cache[unit_id].keys():
				if not is_instance_id_valid(resource_id):
					resource_scores.erase(resource_id)
		else:
			_cache.erase(unit_id)
			
	_cache_dirty = false
		
func _update_scrap_context(unit: Unit, context: ScrapContext, threats: Array[EnemyThreatContext]) -> void:
	var cache:Dictionary[int, ScrapCache] = _cache.get_or_add(unit.get_instance_id(), {} as Dictionary[int, ScrapCache])
	
	var resource_id:int = context.resource.get_instance_id()
	var scrap_cache:ScrapCache = cache.get(resource_id)
	if scrap_cache:
		if _time - scrap_cache.time < resource_cache_duration:
			context.score = scrap_cache.score
			return
	else:
		scrap_cache = ScrapCache.new()
		cache[resource_id] = scrap_cache
	
	var unit_pos:Vector3 = unit.global_position
	var unit_pos2:Vector2 = Vector2(unit_pos.x, unit_pos.z)
	
	var resource_pos:Vector3 = context.resource.global_position
	var resource_pos2:Vector2 = Vector2(resource_pos.x, resource_pos.z)
	
	var to_resource2:Vector2 = resource_pos2 - unit_pos2
	var to_resource_dist_sq:float =  to_resource2.length_squared()
	var to_resource_dist:float = sqrt(to_resource_dist_sq)
	var resource_value:int = context.resource.scrap
	
	var score:float = 1.0 / to_resource_dist * resource_value ** 2

	# Score against all threat contexts
	for threat_context in threats:
		var bounds := threat_context.bounds
		var threat_position:Vector2 = bounds.closest_point_to(unit_pos2)
		
		var to_threat:Vector2 = threat_position - unit_pos2
		
		var proj_threat_resource:float = to_threat.dot(to_resource2) / to_resource_dist_sq
		# If moving away from threat or very far away we get a boost
		if proj_threat_resource < 0.0 or proj_threat_resource >= 2.0:
			score += 10.0 * proj_threat_resource * proj_threat_resource
		else:
			var threat_mult:float = 2.0 - proj_threat_resource
			score -= threat_context.strength * threat_mult
			
	#print("%s: RESOURCE SCORE - %s -> %s=%.1f" % [name, unit.name,  context.resource.name, score])		
	context.score = score
	scrap_cache.score = score
	scrap_cache.time = _time
	
func _get_resources(blackboard:EnemyTeamBlackboard) -> Array[ScrapContext]:
	
	var active_resources:PackedInt64Array = blackboard.active_resources
	var assigned_resources:PackedInt64Array = blackboard.assigned_resources
	
	var resources:Array[ScrapContext]
	resources.resize(active_resources.size())
	
	var count:int = 0
	for id in active_resources:
		if id in assigned_resources:
			continue
		var resource:ScrapToken = instance_from_id(id) as ScrapToken
		if resource:
			var ctx:ScrapContext = ScrapContext.new()
			ctx.resource = resource
			resources[count] = ctx
			count += 1
	resources.resize(count)
	
	return resources
