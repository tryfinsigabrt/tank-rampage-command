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

func _ready() -> void:
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
		
	var resources: Array[ScrapContext] = _get_resources(blackboard.active_resources)
	if not resources:
		return SUCCESS
		
	_time = GameManager.game_timer.time_seconds
	_cache = blackboard.resource_calculation_cache
	
	if _cache_dirty:
		_clean_cache()
	
	var threat_contexts := blackboard.threats
	
	for unit in idle_units:
		if not is_instance_valid(unit):
			continue
			
		for context in resources:
			_update_scrap_context(unit, context, threat_contexts)
		resources.sort_custom(func(a:ScrapContext, b:ScrapContext) -> bool:
			return a.score < b.score
		)
		var selected_context:ScrapContext = resources.back()
		if selected_context.score >= min_resource_score:
			# Move to collect resource
			resources.pop_back()
			unit.get_or_add_actions().move_and_attack(selected_context.resource.global_position)
			
		if not resources:
			break
	# Prioritize and decide whether to move idle units with move and attack to a resource
	# Send multiple units to a resource if it requires an "escort" due to the 	
	return SUCCESS

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
	
func _get_resources(resource_ids:PackedInt64Array) -> Array[ScrapContext]:
	var resources:Array[ScrapContext]
	resources.resize(resource_ids.size())
	
	var count:int = 0
	for id in resource_ids:
		var resource:ScrapToken = instance_from_id(id) as ScrapToken
		if resource:
			var ctx:ScrapContext = ScrapContext.new()
			ctx.resource = resource
			resources[count] = ctx
			count += 1
	resources.resize(count)
	
	return resources
