class_name ThreatScorer extends Node

@onready var cluster_calculator: UnitClustering = $ClusterCalculator

@export
var threat_score_threshold:float = 0.5

@export
var ideal_distance:float = 300.0

var _default_ideal_distance:float

func _ready() -> void:
	_default_ideal_distance = ideal_distance

#region Scoring Modifier
func get_current_scoring_modifier() -> ThreatScoreModifier:
	for child in get_children():
		if child is ThreatScoreModifier:
			return child
	return null
	
func add_scoring_modifier(modifier:ThreatScoreModifier) -> void:
	remove_scoring_modifier()
	add_child(modifier)

func remove_scoring_modifier() -> void:
	for child in get_children():
		if child is ThreatScoreModifier:
			child.queue_free()
			
func apply_scoring_modifier_for(unit:Unit) -> void:
	var weapon:Weapon = unit.weapon
	var current_modifier:ThreatScoreModifier = get_current_scoring_modifier()
	var apply_ranged_score_modifier:bool = not weapon.prefer_close_shots
	
	if apply_ranged_score_modifier and current_modifier is not RangedUnitScoreModifier:
		var modifier := RangedUnitScoreModifier.new()
		modifier.unit = unit
		
		# Change ideal range based on unit weapon
		ideal_distance = MathUtils.mid_point(weapon.ideal_fire_range)
	
		add_scoring_modifier(modifier)
	elif not apply_ranged_score_modifier and current_modifier is RangedUnitScoreModifier:
		remove_scoring_modifier()
		ideal_distance = _default_ideal_distance
		
#endregion
	
func get_threat_assets(assets: Array[Node3D], position:Vector3) -> Array[UnitScore]:
	return _get_threat_assets(assets, position, func(data:Node3D) -> Node3D: return data)
	
func get_visible_threat_assets(assets: Array[UnitData], position:Vector3) -> Array[UnitScore]:
	return _get_threat_assets(assets, position, func(data:UnitData) -> Unit: 
		return data.asset if data.valid and data.visible else null
	)
	
func _get_threat_assets(assets: Array, position:Vector3, viable_asset_extractor:Callable) -> Array[UnitScore]:
	var matches:Array[UnitScore]
	if not assets:
		return matches
	
	var ideal_distance_sq:float = ideal_distance * ideal_distance
	var max_distance_score:float = -INF
	var priority_range:Vector2i = Vector2i(1e9,-1e9)
	var score_components:Dictionary[StringName, float]
	
	var scoring_modifier:ThreatScoreModifier = get_current_scoring_modifier()

	if scoring_modifier:
		scoring_modifier.begin()
		
	# TODO: Placeholder Utility AI - use real utility AI system to score and filter candidates
	for unit_data:Variant in assets:
		var asset:Node3D = viable_asset_extractor.call(unit_data) as Node3D
		if asset and asset.is_in_group(Groups.TeamAsset):
			var attributes:TeamAssetAttributes = asset.attributes
			
			var priority:int = attributes.attack_priority
			priority_range.x = mini(priority, priority_range.x)
			priority_range.y = maxi(priority, priority_range.y)
			
			var entry := UnitScore.new()
			entry.threat = asset
			entry.priority = priority
			
			var dist_sq:float = asset.global_position.distance_squared_to(position)
			entry._dist_sq = dist_sq

			var score:float
			if scoring_modifier:
				score = scoring_modifier.get_distance_score(entry, position)
			else:
				score = ideal_distance_sq / maxf(dist_sq, 0.001)
				
			max_distance_score = maxf(score, max_distance_score)
			entry.score = score
			matches.push_back(entry)
	
	if not matches:
		return matches
		
	# Normalize dist scores and factor in priority scoring
	var max_score:float = -INF
	for entry in matches:
		var norm_dist_score:float = entry.score / max_distance_score
		# Lower priority is a higher score so reverse the ilerp
		# inverse_lerp with x = y is nan so handle that special case
		var priority_score:float = inverse_lerp(priority_range.y, priority_range.x, entry.priority) if priority_range.x != priority_range.y else 1.0
		var total_score:float
		if scoring_modifier:
			score_components[&"dist"] = norm_dist_score
			score_components[&"priority"] = priority_score
			total_score = scoring_modifier.get_final_score(entry, score_components)
		else:
			total_score = norm_dist_score * 0.6 + priority_score * 0.4
		max_score = maxf(total_score, max_score)
		
		entry.score = total_score
	
	if scoring_modifier:
		scoring_modifier.end()
		
	# Renormalize
	for entry in matches:
		entry.score = entry.score / max_score
		
	matches.sort_custom(func(a:UnitScore, b:UnitScore) -> bool:
		return a.score > b.score
	)
	
	var remove_index_start:int = -1
	for i in range(matches.size() - 1, -1, -1):
		var entry := matches[i]
		if entry.score < threat_score_threshold:
			remove_index_start = i
			break
			
	# Remove from the removal index start by truncating the array
	if remove_index_start >= 0:
		matches.resize(remove_index_start)
		
	return matches	

func calculate_threat_inputs(units: Array[Unit], threats:Array[Unit]) -> Array[UnitThreatContext]:
	var unit_clusters:Array[UnitClustering.UnitCluster] = cluster_calculator.compute_clusters(units)
	var threat_clusters:Array[UnitClustering.UnitCluster] = cluster_calculator.compute_clusters(threats)
	var contexts: Array[UnitThreatContext]
	
	if not unit_clusters or not threat_clusters:
		return contexts
		
	var friendly_cluster_strengths:PackedFloat32Array
	friendly_cluster_strengths.resize(unit_clusters.size())
	
	for threat_cluster in threat_clusters:
		var min_dist_sq:float = INF
		var friendly_cluster_index:int = -1
	
		var threat_center:Vector2 = threat_cluster.center
		for i in unit_clusters.size():
			var unit_cluster:UnitClustering.UnitCluster = unit_clusters[i]
			var dist_sq:float = threat_center.distance_squared_to(unit_cluster.center)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				friendly_cluster_index = i
		
		var friendly_cluster_strength:float = friendly_cluster_strengths[friendly_cluster_index]
		if friendly_cluster_strength == 0.0:
			for unit in unit_clusters[friendly_cluster_index].units:
				friendly_cluster_strength += unit.strength()
			friendly_cluster_strengths[friendly_cluster_index] = friendly_cluster_strength
			
		var min_dist:float = sqrt(min_dist_sq)
		
		var threat_strength:float = 0.0
		for threat in threat_cluster.units:
			threat_strength += threat.strength()
			
		var context: UnitThreatContext = UnitThreatContext.new()
		
		context.threat_cluster = threat_cluster
		context.friendly_cluster = unit_clusters[friendly_cluster_index]
		context.distance = min_dist
		context.threat_cluster_strength = threat_strength
		context.assist_cluster_strength = friendly_cluster_strength
		
		contexts.push_back(context)
	
	return contexts
